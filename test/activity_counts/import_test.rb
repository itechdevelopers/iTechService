# Isolated PostgreSQL integration tests. Never loads production Rails config.
require 'bundler/setup'
require 'active_record'
require 'active_support/all'
require 'minitest/autorun'
require 'pg'
Time.zone = 'Vladivostok'

raise 'Use the isolated test port' unless ENV['ACTIVITY_TEST_PORT'] == '55438'
connection = PG.connect(host: '127.0.0.1', port: 55438, user: 'ais_test', dbname: 'postgres')
connection.exec('CREATE DATABASE activity_counts_test') unless connection.exec("SELECT 1 FROM pg_database WHERE datname='activity_counts_test'").any?
connection.close
ActiveRecord::Base.establish_connection(adapter: 'postgresql', host: '127.0.0.1', port: 55438, username: 'ais_test', database: 'activity_counts_test')
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
class Department < ApplicationRecord; end
require_relative '../../db/migrate/20260924050000_create_activity_count_snapshots'
ActiveRecord::Migration.verbose = false
CreateActivityCountSnapshots.new.migrate(:up) unless ActiveRecord::Base.connection.table_exists?(:activity_count_imports)
c = ActiveRecord::Base.connection
c.execute('CREATE TABLE IF NOT EXISTS departments (id serial PRIMARY KEY, name text)')
c.execute('CREATE TABLE IF NOT EXISTS locations (id serial PRIMARY KEY, department_id integer, code text)')
c.execute('CREATE TABLE IF NOT EXISTS history_records (id serial PRIMARY KEY, object_id integer, object_type text, column_name text, old_value text, new_value text, created_at timestamp, deleted_at timestamp)')
require_relative '../../app/models/activity_count_import'
require_relative '../../app/models/activity_count_day'
require_relative '../../app/services/activity_counts/import'
require_relative '../../app/services/activity_counts/refresh_repairs'

class ActivityCountImportTest < Minitest::Test
  def setup
    ActiveRecord::Base.connection.execute('TRUNCATE activity_count_days, activity_count_imports, departments, locations, history_records RESTART IDENTITY CASCADE')
  end

  def report(quantity = 2, stamp = '2026-01-03T00:00:00Z')
    {'schema_version'=>'activity-counts-1.0','metric'=>'receipts','methodology_version'=>'posted-receipts-1.0',
     'period'=>{'from'=>'2026-01-01','to'=>'2026-01-02'},'calculated_at'=>stamp,
     'source'=>{'read_only'=>true,'http_methods'=>['GET']},'checks'=>{'all_pages_received'=>true,'duplicates'=>0},
     'quantity'=>quantity,'days'=>[
       {'date'=>'2026-01-01','quantity'=>quantity,'branches'=>[{'id'=>'branch-a','name'=>'Магазин','quantity'=>quantity}]},
       {'date'=>'2026-01-02','quantity'=>0,'branches'=>[]}]}
  end

  def deliver(data, id = 'a')
    ActivityCounts::Import.call(delivery_id:id*64, report:data)
  end

  def test_idempotency_and_immutable_source_versions
    record, status = deliver(report)
    assert_equal :created, status
    again, status = deliver(report)
    assert_equal :duplicate, status
    assert_equal record.id, again.id
    assert_equal 1, ActivityCountImport.count
    assert_equal 2, ActivityCountDay.count
    deliver(report(5,'2026-01-04T00:00:00Z'),'b')
    assert_equal 5, ActivityCountDay.sum(:quantity)
    assert_equal 2, record.reload.payload['quantity']
    deliver(report(99,'2026-01-02T00:00:00Z'),'c')
    assert_equal 5, ActivityCountDay.sum(:quantity), 'old delivery must not replace corrected values'
  end

  def test_incomplete_or_inconsistent_snapshot_preserves_previous
    deliver(report)
    invalid=report(10); invalid['days'].pop
    assert_raises(ActivityCounts::Import::InvalidReport) { deliver(invalid,'b') }
    invalid=report(10);invalid['days'][0]['branches'][0]['quantity']=9
    assert_raises(ActivityCounts::Import::InvalidReport) { deliver(invalid,'c') }
    assert_equal 2, ActivityCountDay.sum(:quantity)
    assert_equal 1, ActivityCountImport.count
  end

  def test_api_contract_cannot_import_repairs_or_future_days
    data=report;data['metric']='issued_repairs'
    assert_raises(ActivityCounts::Import::InvalidReport) { deliver(data) }
    data=report;data['checks']['duplicates']=1
    assert_raises(ActivityCounts::Import::InvalidReport) { deliver(data) }
    data=report;data['source']['http_methods']=['POST']
    assert_raises(ActivityCounts::Import::InvalidReport) { deliver(data) }
  end

  def test_concurrent_deliveries_publish_newest_snapshot_once
    results = []
    threads = [1, 2].map do |n|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results << deliver(report(n, "2026-01-0#{n+3}T00:00:00Z"), n.to_s)
        end
      end
    end
    threads.each(&:value)
    assert_equal 2, ActivityCountImport.count
    assert_equal 2, ActivityCountDay.count
    assert_equal 2, ActivityCountDay.sum(:quantity)
  end

  def test_failed_publication_rolls_back_all_days
    deliver(report)
    connection=ActiveRecord::Base.connection
    connection.execute("ALTER TABLE activity_count_days ADD CONSTRAINT test_count_limit CHECK (quantity < 5)")
    assert_raises(ActiveRecord::StatementInvalid) { deliver(report(8,'2026-01-04T00:00:00Z'),'b') }
    assert_equal 2, ActivityCountDay.sum(:quantity)
    assert_equal 1, ActivityCountImport.count
  ensure
    connection.execute('ALTER TABLE activity_count_days DROP CONSTRAINT IF EXISTS test_count_limit')
  end

  def test_partial_initial_history_is_resumed_by_an_ordinary_run
    partial = report(0)
    partial['metric'] = 'issued_repairs'
    partial['methodology_version'] = 'first-archive-issue-1.0'
    partial['period'] = {'from'=>'2020-01-01','to'=>'2020-01-01'}
    partial['days'] = [{'date'=>'2020-01-01','quantity'=>0,'branches'=>[]}]
    ActivityCounts::Import.call(delivery_id:'d'*64,report:partial,allowed_metric:'issued_repairs')
    ActivityCounts::RefreshRepairs.call(full:false,today:Date.new(2026,1,6))
    assert_equal 366, ActivityCountDay.where(date: Date.new(2020,1,1)..Date.new(2020,12,31)).count
    assert_equal 365, ActivityCountDay.where(date: Date.new(2025,1,1)..Date.new(2025,12,31)).count
    assert_equal 5, ActivityCountDay.where(date: Date.new(2026,1,1)..Date.new(2026,1,5)).count
  end

  def test_first_issue_and_historical_branch_not_current_job_location
    c=ActiveRecord::Base.connection
    c.execute("INSERT INTO departments VALUES (1,'Первый'),(2,'Второй')")
    c.execute("INSERT INTO locations VALUES (1,1,'done'),(2,1,'archive'),(3,2,'archive')")
    # A repeat in 2026 must not recount a job first issued in 2020.
    c.execute(<<~SQL)
      INSERT INTO history_records(object_id,object_type,column_name,old_value,new_value,created_at) VALUES
      (101,'ServiceJob','location_id','1','2','2020-01-02 20:00:00'),
      (101,'ServiceJob','location_id','1','3','2026-01-03 01:00:00'),
      (102,'ServiceJob','location_id','1','3','2026-01-03 20:00:00'),
      (103,'ServiceJob','location_id','2','3','2026-01-03 01:00:00'),
      (104,'ServiceJob','location_id',NULL,'3','2026-01-03 01:00:00'),
      (NULL,'ServiceJob','location_id','1','3','2026-01-03 01:00:00')
    SQL
    ActivityCounts::RefreshRepairs.call(full:true,today:Date.new(2026,1,6))
    assert_equal 2, ActivityCountDay.sum(:quantity)
    old=ActivityCountDay.find_by!(date:'2020-01-03')
    assert_equal '1',old.branches.first['id']
    recent=ActivityCountDay.find_by!(date:'2026-01-04')
    assert_equal 1,recent.quantity
    assert_equal '2',recent.branches.first['id']
    assert_equal 0,ActivityCountDay.find_by!(date:'2026-01-05').quantity
  end
end
