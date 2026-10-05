# frozen_string_literal: true
# Dedicated local database only. Never load the ordinary test helper or external jobs.
abort 'Set RAILS_ENV=test' unless ENV['RAILS_ENV'] == 'test'
# Do not rely on ActiveSupport before boot.
unless ENV['DB_HOST'] == '127.0.0.1' && ENV['DB_NAME_TEST'] == 'ais_mcp_isolated_test' && ENV['DB_PORT'].to_s.match?(/\A\d+\z/)
  abort 'Only dedicated loopback MCP test DB allowed'
end
ENV['NEW_RELIC_AGENT_ENABLED'] = 'false'
ENV['AIS_MCP_ENABLED'] = '1'
ENV['AIS_MCP_PUBLIC_ORIGIN'] = 'https://ais.example'
ENV['AIS_MCP_OAUTH_CLIENT_ID'] = 'test-client'
ENV['AIS_MCP_OAUTH_REDIRECT_URIS'] = 'https://chatgpt.example/callback'
ENV['SECRET_KEY_BASE'] = 'mcp-test-only-' * 8
ENV['DEVISE_SECRET_KEY'] = 'mcp-test-only-' * 8
ENV.delete('TELEGRAM_BOT_TOKEN')
ENV.delete('CLIENT_TELEGRAM_BOT_TOKEN')
require 'bundler/setup'
# Browser tests are not exercised here. Skip the known incompatible helper only
# in this process; no project dependency or production runtime changes.
spec = Gem.loaded_specs.fetch('chromedriver-helper')
$LOADED_FEATURES << File.join(spec.full_gem_path, 'lib/chromedriver-helper.rb')
require_relative '../../config/environment'
require 'minitest/autorun'
require 'mocha/minitest'
require 'net/http'
module NoMcpTestNetwork
  def request(*)
    raise 'External HTTP is forbidden in MCP tests'
  end
end
Net::HTTP.prepend(NoMcpTestNetwork)
HTTPClient.prepend(NoMcpTestNetwork) if defined?(HTTPClient)
ActiveJob::Base.queue_adapter = :test
abort 'Unexpected DB connection' unless ActiveRecord::Base.connection.current_database == 'ais_mcp_isolated_test'
if ENV['AIS_MCP_TEST_PREPARE'] == '1'
  ActiveRecord::Schema.verbose = false
  load Rails.root.join('db/schema.rb') unless ActiveRecord::Base.connection.table_exists?(:users)
  require_relative '../../db/migrate/20261005000000_create_mcp_credentials_and_writes'
  CreateMcpCredentialsAndWrites.new.migrate(:up) unless ActiveRecord::Base.connection.table_exists?(:mcp_credentials)
end

module McpTestFixtures
  def setup
    super
    ActiveRecord::Base.connection.execute('TRUNCATE users, departments, cities, locations, clients, orders, service_jobs, repair_statuses, repair_pause_reasons, weekly_markup_imports, audits, approval_requests, user_settings, device_notes, announcements, history_records, record_edits RESTART IDENTITY CASCADE')
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    NotificationDispatcher.stubs(:call)
    UserNotificationChannel.stubs(:broadcast_to)
    @city = raw(City, name: 'Test city')
    @department = raw(Department, name: 'Test store', code: 'test', role: 1, city_id: @city.id)
    @location = raw(Location, name: 'Repair', code: 'repair', department_id: @department.id)
    @user = raw(User, username: 'test-actor', role: 'technician', department_id: @department.id, location_id: @location.id)
    raw(UserSettings, user_id: @user.id)
    User.current = @user
    @client = raw(Client, name: 'Test', surname: 'Only', phone_number: '2345678', full_phone_number: '74232345678', department_id: @department.id, category: 0)
    @order = raw(Order, number: 'N-1', customer_type: 'Client', customer_id: @client.id, object_kind: 'accessory', object: 'Test fixture', department_id: @department.id, user_id: @user.id, status: 'current')
    @waiting = raw(RepairStatus, code: 'waiting', name: 'Waiting', color: '#cccccc')
    @progress = raw(RepairStatus, code: 'in_progress', name: 'In progress', color: '#cccccc')
    @paused = raw(RepairStatus, code: 'paused', name: 'Paused', color: '#cccccc')
    @completed = raw(RepairStatus, code: 'completed', name: 'Completed', color: '#cccccc')
    @job = raw(ServiceJob, ticket_number: 'N-1', client_id: @client.id, user_id: @user.id, department_id: @department.id, location_id: @location.id, repair_status_id: @waiting.id, contact_phone: '+7 (423) 234-56-78')
  end
  def teardown
    User.current = nil
    super
  end
  # Synthetic fixture inserts bypass creation side effects; tools use REAL models.
  def raw(klass, attributes)
    conn = ActiveRecord::Base.connection
    values = attributes.merge(created_at: Time.current, updated_at: Time.current)
    values = values.select { |key,_| klass.column_names.include?(key.to_s) }
    columns = values.keys.map { |key| conn.quote_column_name(key) }.join(',')
    literals = values.values.map { |value| conn.quote(value) }.join(',')
    id = conn.select_value("INSERT INTO #{conn.quote_table_name(klass.table_name)} (#{columns}) VALUES (#{literals}) RETURNING id")
    klass.find(id)
  end
  def tool(name, args = nil, user: @user, scopes: Mcp::Configuration::SCOPES, **attributes)
    Mcp::Tools.new(user, scopes).call(name, args || attributes)
  end
  def ref
    {kind: 'order', id: @order.id}
  end
  def write_args
    ref.merge(content: 'Synthetic comment', request_key: 'request-key-000001')
  end
  def oauth_params
    verifier = 'v' * 64
    {client_id: 'test-client', redirect_uri: 'https://chatgpt.example/callback', response_type: 'code', scope: 'ais:read ais:write', state: 'test-state', resource: 'https://ais.example/mcp', code_challenge_method: 'S256', code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)}
  end
  def authorization_code
    p = oauth_params
    McpCredential.issue!(kind: 'code', user: @user, client_id: p[:client_id], resource: p[:resource], scope: p[:scope], redirect_uri: p[:redirect_uri], code_challenge: p[:code_challenge], expires_at: 5.minutes.from_now)
  end
  def exchange(code)
    {grant_type: 'authorization_code', code: code, client_id: 'test-client', resource: 'https://ais.example/mcp', redirect_uri: 'https://chatgpt.example/callback', code_verifier: 'v' * 64}
  end
end

if ENV['AIS_MCP_TEST_DUMP_SCHEMA'] == '1'
  ActiveRecord::SchemaMigration.find_or_create_by!(version: '20261005000000')
  File.open(Rails.root.join('db/schema.rb'), 'w') { |f| ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, f) }
end
