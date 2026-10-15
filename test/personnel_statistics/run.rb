# Isolated Rails regression; never run against the production database.
ENV['RAILS_ENV'] ||= 'development'
require_relative '../../config/environment'
require 'minitest/autorun'
require 'rack/test'
require 'warden/test/helpers'
abort 'Use ais_telephony_test only' unless ActiveRecord::Base.connection.current_database == 'ais_telephony_test'

class PersonnelReviewStatisticsTest < Minitest::Test
  include Rack::Test::Methods
  include Warden::Test::Helpers
  def app; Rails.application; end

  def insert(model, attrs)
    connection = model.connection
    attrs = {created_at: Time.current, updated_at: Time.current}.merge(attrs).select { |key, _| model.column_names.include?(key.to_s) }
    columns = attrs.keys.map { |key| connection.quote_column_name(key) }.join(',')
    values = attrs.values.map { |value| connection.quote(value) }.join(',')
    model.find(connection.select_value("INSERT INTO #{connection.quote_table_name(model.table_name)} (#{columns}) VALUES (#{values}) RETURNING id"))
  end

  def setup
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @city = insert(City, name: 'Город отзывов', time_zone: 'Vladivostok')
    @other_city = insert(City, name: 'Другой город', time_zone: 'Moscow')
    brand = insert(Brand, name: 'Тест')
    @department = insert(Department, name: 'Первый филиал', code: 'review-first', city_id: @city.id, brand_id: brand.id, role: 1)
    @second = insert(Department, name: 'Второй филиал', code: 'review-second', city_id: @city.id, brand_id: brand.id, role: 1)
    @foreign = insert(Department, name: 'Чужой филиал', code: 'review-foreign', city_id: @other_city.id, brand_id: brand.id, role: 1)
    @user = employee('Автор', @department, 31)
    @no_activity = employee('Без флажка', @second, 0)
    @month = Date.new(2026, 10, 1)
    User.current = @user
    @seq = 0
  end

  def teardown
    User.current = nil
    Warden.test_reset!
    ActiveRecord::Base.connection.rollback_transaction
  end

  def employee(name, department, mask)
    user = insert(User, username: "review-stat-#{name}", name: name, surname: 'Тестовый', role: 'software', department_id: department.id,
                  activities_mask: mask, encrypted_password: Devise::Encryptor.digest(User, 'Review-test-pass1'))
    insert(UserSettings, user_id: user.id)
    user
  end

  def review(**attrs)
    @seq += 1
    insert(GisReview, {external_review_id: "review-stat-#{@seq}", city_name: @city.name, city_id: @city.id,
      department_id: @department.id, source: '2gis', status: 0, user_id: @user.id,
      reviewed_at: Time.iso8601('2026-10-15T12:00:00+10:00'), rating: 5}.merge(attrs))
  end

  def counts(**attrs)
    EmployeeStatisticsQuery.new(metric: 'reviews', month: @month, city_id: @city.id, **attrs).call.to_h { |user, count| [user.id, count] }
  end

  def test_only_confirmed_current_owner_from_requested_sources
    review
    review(source: 'yandex')
    review(source: 'vl_ru')
    unassigned = review(status: 1, user_id: nil)
    insert(GisReviewClaim, gis_review_id: unassigned.id, user_id: @user.id, status: 0)
    review(status: 2)
    review(user_id: nil)
    reassigned = review(user_id: @no_activity.id)
    insert(GisReviewClaim, gis_review_id: reassigned.id, user_id: @user.id, status: 1)
    assert_equal 2, counts[@user.id]
    assert_equal 1, counts[@no_activity.id]
  end

  def test_publication_date_and_city_timezone_boundaries_not_import_time
    review(reviewed_at: Time.iso8601('2026-10-01T00:00:00+10:00'), created_at: Time.iso8601('2026-11-10T12:00:00+10:00'))
    review(reviewed_at: Time.iso8601('2026-10-31T23:59:59+10:00'))
    review(reviewed_at: Time.iso8601('2026-09-30T23:59:59+10:00'))
    review(reviewed_at: Time.iso8601('2026-11-01T00:00:00+10:00'))
    assert_equal 2, counts[@user.id]
  end

  def test_department_follows_review_branch_even_if_employee_moved
    review(user_id: @no_activity.id)
    review(user_id: @user.id, department_id: @second.id)
    review(city_id: @other_city.id, department_id: @foreign.id)
    assert_equal 1, counts(department_id: @department.id)[@no_activity.id]
    assert_equal 0, counts(department_id: @department.id)[@user.id]
    assert_equal({@user.id => 1}, counts(department_id: @second.id).reject { |_, value| value.zero? })
  end

  def test_custom_period_includes_whole_last_day
    review(reviewed_at: Time.iso8601('2026-10-15T00:00:00+10:00'))
    review(reviewed_at: Time.iso8601('2026-10-15T23:59:59+10:00'))
    review(reviewed_at: Time.iso8601('2026-10-16T00:00:00+10:00'))
    assert_equal 2, counts(from_date: Date.new(2026,10,15), to_date: Date.new(2026,10,15))[@user.id]
  end

  def test_zero_rows_and_other_metrics_keep_existing_activity_bits
    assert_equal 0, counts[@user.id]
    refute counts.key?(@no_activity.id)
    %w[free fast long mac].each do |metric|
      result = EmployeeStatisticsQuery.new(metric: metric, month: @month, city_id: @city.id).call
      assert_equal [[@user, 0]], result
    end
    assert_equal %w[free fast long mac reviews], User::ACTIVITIES
  end

  def test_page_filters_and_plan_scope
    review
    login_as(@user, scope: :user)
    get '/personnel/statistics', metric: 'reviews', month: @month.to_s, city_id: @city.id
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Отзывы'
    assert_includes last_response.body, 'name="department_id"'
    assert_includes last_response.body, 'name="from_date"'
    assert_includes last_response.body, 'employee-statistics__plan-row'
    get '/personnel/statistics', metric: 'reviews', month: @month.to_s, city_id: @city.id, department_id: @department.id,
                                  from_date: '2026-10-15', to_date: '2026-10-15'
    assert_equal 200, last_response.status
    refute_includes last_response.body, 'employee-statistics__plan-row'
    assert_includes last_response.body, 'Первый филиал'
    if ENV['AIS_STATISTICS_FIXTURE']
      File.write(ENV.fetch('AIS_STATISTICS_FIXTURE'), last_response.body)
      File.write(ENV.fetch('AIS_STATISTICS_FIXTURE') + '.css', Rails.application.assets['application.css'].to_s)
    end
  end

  def test_invalid_period_and_foreign_department_do_not_change_scope
    login_as(@user, scope: :user)
    get '/personnel/statistics', metric: 'reviews', month: @month.to_s, city_id: @city.id,
                                  department_id: @foreign.id, from_date: '2026-10-31', to_date: '2026-10-01'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'value="2026-10-01"'
    assert_includes last_response.body, 'employee-statistics__plan-row'
    refute_includes last_response.body, @foreign.name
    ['0000-10-01', '99999999-10-01', 'not-a-date'].each do |date|
      get '/personnel/statistics', metric: 'reviews', month: @month.to_s, city_id: @city.id,
                                    from_date: date, to_date: date
      assert_equal 200, last_response.status
      assert_includes last_response.body, 'value="2026-10-01"'
    end
  end

  def test_reviews_plan_is_valid_and_requires_authentication
    assert Plan.new(city: @city, month: @month, metric: 'reviews', target: 5).valid?
    get '/personnel/statistics', metric: 'reviews'
    assert_includes [302, 401], last_response.status
  end
end
