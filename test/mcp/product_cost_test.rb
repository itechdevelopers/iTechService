# frozen_string_literal: true
# Dedicated disposable database. This helper does not load the normal test suite.
abort 'Only disposable loopback cost test DB is allowed' unless ENV['RAILS_ENV'] == 'test' &&
  ENV['DB_HOST'] == '127.0.0.1' && ENV['DB_NAME_TEST'] == 'ais_mcp_cost_test'
ENV['NEW_RELIC_AGENT_ENABLED'] = 'false'
ENV['SECRET_KEY_BASE'] = 'cost-test-only-' * 8
ENV['DEVISE_SECRET_KEY'] = 'cost-test-only-' * 8
require 'bundler/setup'
spec = Gem.loaded_specs.fetch('chromedriver-helper')
$LOADED_FEATURES << File.join(spec.full_gem_path, 'lib/chromedriver-helper.rb')
require_relative '../../config/environment'
require 'minitest/autorun'
require 'mocha/minitest'
require 'rack/test'
require 'tmpdir'
require 'net/http'
module CostTestNoNetwork
  def request(*)
    raise 'External HTTP is forbidden in tests'
  end
end
Net::HTTP.prepend(CostTestNoNetwork)
ActiveJob::Base.queue_adapter = :test
abort 'Unexpected database' unless ActiveRecord::Base.connection.current_database == 'ais_mcp_cost_test'
if ENV['AIS_MCP_COST_TEST_PREPARE'] == '1'
  ActiveRecord::Schema.verbose = false
  load Rails.root.join('db/schema.rb') unless ActiveRecord::Base.connection.table_exists?(:users)
end

class ProductCostApiTest < Minitest::Test
  include Rack::Test::Methods
  def app; Rails.application; end

  def setup
    conn = ActiveRecord::Base.connection
    conn.execute('TRUNCATE users RESTART IDENTITY CASCADE')
    # Synthetic identities without user creation notifications/jobs.
    @user = User.find(conn.select_value("INSERT INTO users (username, role, authentication_token, created_at, updated_at) VALUES ('cost-test', 'technician', 'cost-test-token', NOW(), NOW()) RETURNING id"))
  end

  def request_cost
    get '/api/v1/products/cost_by_barcode', { barcode: '00123' }, { 'HTTP_AUTHORIZATION' => 'Token token=cost-test-token' }
  end

  def test_permission_rejected_before_connector
    OneCProductCost.expects(:call).never
    request_cost
    assert_equal 403, last_response.status
  end

  def test_superadmin_uses_exact_string_and_returns_result
    @user.update_columns(role: 'superadmin')
    OneCProductCost.expects(:call).with { |args| args['barcode'] == '00123' }.returns({ status: 'ok', barcode: '00123', cost_per_unit: '25.125' })
    request_cost
    assert_equal 200, last_response.status
    assert_equal '00123', JSON.parse(last_response.body)['barcode']
  end

  def test_1c_error_is_safe_502
    @user.update_columns(role: 'superadmin')
    OneCProductCost.expects(:call).raises(OneCProductCost::Unavailable)
    request_cost
    assert_equal 502, last_response.status
    refute_includes last_response.body, 'password'
  end

  def test_bad_arguments_422
    @user.update_columns(role: 'superadmin')
    OneCProductCost.expects(:call).raises(OneCProductCost::InvalidArguments, 'barcode must be a string')
    request_cost
    assert_equal 422, last_response.status
  end

  def test_anonymous_request_does_not_reach_connector
    OneCProductCost.expects(:call).never
    get '/api/v1/products/cost_by_barcode', { barcode: '00123' }
    assert_equal 401, last_response.status
  end
end

class ProductCostProcessTest < Minitest::Test
  def with_connector
    old = ENV['AIS_MCP_ODATA_CONNECTOR']
    Dir.mktmpdir('cost-test-') do |directory|
      Dir.mkdir(File.join(directory, 'local'))
      File.write(File.join(directory, 'local/metadata.xml'), 'fixture')
      File.write(File.join(directory, 'odata.py'), <<~PYTHON)
        from test_product_cost import API, Schema as BaseSchema, FixtureClient
        SafeError = API.SafeError
        guid, moment, literal = API.guid, API.moment, API.literal
        SAFE_FUNCTIONS = set()
        def credentials(): return ('fixture', 'fixture')
        class Schema(BaseSchema):
            def __init__(self, data): pass
        class Client(FixtureClient):
            def __init__(self, credentials, schema): super().__init__()
      PYTHON
      ENV['AIS_MCP_ODATA_CONNECTOR'] = directory
      yield
    end
  ensure
    ENV['AIS_MCP_ODATA_CONNECTOR'] = old
  end

  def test_fixed_python_process_success_with_fixture_connector
    with_connector do
      result = OneCProductCost.call(barcode: '00123')
      assert_equal '00123', result['barcode']
      assert_equal '25.125', result['breakdown'][0]['cost_per_unit']
    end
  end

  def test_invalid_barcode_is_mapped_from_python
    with_connector do
      assert_raises(OneCProductCost::InvalidArguments) { OneCProductCost.call(barcode: 123) }
    end
  end
end
