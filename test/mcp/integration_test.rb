# frozen_string_literal: true
require_relative 'helper'
require 'action_dispatch/testing/integration'

class McpIntegrationTest < ActionDispatch::IntegrationTest
  include McpTestFixtures
  include Devise::Test::IntegrationHelpers

  def test_search_empty_ambiguous_and_normalized_phone
    assert_empty tool('search_orders', number: 'absent')[:matches]
    assert_equal %w[order service_job], tool('search_orders', number: 'N-1')[:matches].map { |r| r[:kind] }
    assert_equal 2, tool('search_orders', phone: '+7 (423) 234-56-78')[:matches].length
    assert_equal 2, tool('search_orders', phone: '2345678')[:matches].length
    assert_raises(Mcp::Tools::Error) { tool('search_orders', {}) }
    assert_raises(Mcp::Tools::Error) { tool('search_orders', number: 'N-1', phone: '2345678') }
    assert_raises(Mcp::Tools::Error) { tool('get_order', kind: 'order', id: '1') }
  end

  def test_comment_replay_payload_conflict_and_audit_actor
    first = tool('add_order_comment', write_args)
    second = tool('add_order_comment', write_args)
    assert_equal first.as_json, second.as_json
    assert_equal 1, @order.notes.count
    assert_equal @user.id, @order.notes.first.author_id
    assert_equal @user.id, Audited::Audit.last.user_id
    assert_equal 1, McpWrite.count
    assert_equal 'succeeded', McpWrite.first.outcome
    assert_raises(Mcp::Tools::Error) { tool('add_order_comment', write_args.merge(content: 'Different')) }
    assert_equal 1, @order.notes.count
  end

  def test_write_requires_scope_and_current_policy_even_on_replay
    assert_raises(Mcp::Tools::Error) { tool('add_order_comment', write_args, scopes: ['ais:read']) }
    args = ref.merge(status: 'pending', expected_status: 'current', request_key: 'request-key-000002')
    tool('change_order_status', args)
    @order.update_columns(user_id: nil)
    @user.update_columns(role: 'programmer')
    assert_raises(Mcp::Tools::Error) { tool('change_order_status', args) }
    @user.update_columns(is_fired: true)
    assert_raises(Mcp::Tools::Error) { tool('get_order', ref) }
  end

  def test_order_sequential_transition_archive_and_stale_expected_state
    args = ref.merge(status: 'archive', expected_status: 'current', request_key: 'request-key-000003')
    assert_raises(Mcp::Tools::Error) { tool('change_order_status', args) }
    assert_equal 'current', @order.reload.status
    tool('change_order_status', args.merge(status: 'pending'))
    assert_equal 'pending', @order.reload.status
    assert_raises(Mcp::Tools::Error) { tool('change_order_status', args.merge(status: 'on_the_way', request_key: 'request-key-000004')) }
    @order.update_columns(status: 'notified')
    args = args.merge(expected_status: 'notified', request_key: 'request-key-000005')
    assert_raises(Mcp::Tools::Error) { tool('change_order_status', args) }
    tool('change_order_status', args.merge(archive_reason: 'order_picked_up'))
    assert_equal 'archive', @order.reload.status
    assert_equal 'order_picked_up', @order.archive_reason
  end

  def test_repair_status_business_layer_and_repeat
    args = {kind: 'service_job', id: @job.id, status: 'in_progress', expected_status: 'waiting', request_key: 'request-key-000006'}
    tool('change_order_status', args)
    tool('change_order_status', args)
    assert_equal 'in_progress', @job.reload.repair_status.code
    assert_equal 1, @job.repair_status_changes.count
    assert_equal @user.id, @job.repair_status_changes.first.user_id
    assert_raises(Mcp::Tools::Error) { tool('change_order_status', args.merge(status: 'completed', expected_status: 'in_progress', request_key: 'request-key-000007')) }
  end

  def test_testing_pause_outbox_and_replay_only_one_session
    reason = raw(RepairPauseReason, code: 'testing', name: 'Testing')
    args = {kind: 'service_job', id: @job.id, status: 'paused', expected_status: 'waiting', request_key: 'request-key-000008', pause_reason_id: reason.id}
    assert_raises(Mcp::Tools::Error) { tool('change_order_status', args) }
    args = args.merge(target_location_id: @location.id, what_to_test: 'Synthetic fixture only')
    tool('change_order_status', args)
    tool('change_order_status', args)
    assert_equal 1, @job.testing_sessions.count
    assert_equal 2, ActiveJob::Base.queue_adapter.enqueued_jobs.length
    assert McpWrite.first.dispatched_at
    assert_equal 2, McpWrite.first.outbox.length
  end

  def test_finance_permissions_missing_dates_and_inclusive_business_timezone
    assert_raises(Mcp::Tools::Error) { tool('revenue_summary', from: '2026-10-01', to: '2026-10-02') }
    @user.update_columns(role: 'superadmin')
    result = tool('revenue_summary', from: '2026-10-01', to: '2026-10-02')
    assert_equal 'Asia/Vladivostok', result[:period][:time_zone]
    assert_equal %w[2026-10-01 2026-10-02], result[:missing_dates]
    assert_equal false, result[:complete]
    assert_raises(Mcp::Tools::Error) { tool('revenue_summary', from: '2026-10-02', to: '2026-10-01') }
    assert_raises(Mcp::Tools::Error) { tool('revenue_summary', from: '2026-01-01', to: '2028-01-01') }
  end

  def test_oauth_code_pkce_resource_binding_single_use_rotation_and_revocation
    code = authorization_code
    assert_raises(Mcp::Oauth::Error) { Mcp::Oauth.exchange(exchange(code).merge(code_verifier: 'x' * 64)) }
    assert_raises(Mcp::Oauth::Error) { Mcp::Oauth.exchange(exchange(code).merge(resource: 'https://other.example/mcp')) }
    result = Mcp::Oauth.exchange(exchange(code))
    assert_equal 'Bearer', result[:token_type]
    assert McpCredential.lookup(result[:access_token], 'access').usable?
    assert_raises(Mcp::Oauth::Error) { Mcp::Oauth.exchange(exchange(code)) }
    refresh = {grant_type: 'refresh_token', refresh_token: result[:refresh_token], client_id: 'test-client', resource: 'https://ais.example/mcp'}
    rotated = Mcp::Oauth.exchange(refresh)
    refute_equal result[:access_token], rotated[:access_token]
    assert_raises(Mcp::Oauth::Error) { Mcp::Oauth.exchange(refresh) }
    refute McpCredential.lookup(rotated[:access_token], 'access').usable?
    @user.update_columns(is_fired: true)
    refute McpCredential.lookup(rotated[:access_token], 'access').usable?
    refute McpCredential.pluck(:digest).include?(rotated[:access_token])
  end

  def test_oauth_rejects_unregistered_callback_client_scope_and_plain_pkce
    assert Mcp::Oauth.authorization_parameters(oauth_params)
    [:redirect_uri, :client_id, :resource, :scope, :code_challenge_method].each do |key|
      assert_raises(Mcp::Oauth::Error) { Mcp::Oauth.authorization_parameters(oauth_params.merge(key => 'invalid')) }
    end
  end

  def test_http_auth_metadata_and_business_error_responses
    get '/.well-known/oauth-authorization-server'
    assert_equal 200, response.status
    assert_includes JSON.parse(response.body)['code_challenge_methods_supported'], 'S256'
    get '/mcp/ais/identity'
    assert_equal 401, response.status
    token = Mcp::Oauth.exchange(exchange(authorization_code))[:access_token]
    headers = {'Authorization' => "Bearer #{token}"}
    get '/mcp/ais/identity', headers: headers
    assert_equal 200, response.status
    post '/mcp/ais/call', params: {tool: 'get_order', arguments: {kind: 'order', id: 999999}}, headers: headers, as: :json
    assert_equal 404, response.status
    post '/mcp/ais/call', params: {tool: 'change_order_status', arguments: ref.merge(status: 'archive', expected_status: 'current', request_key: 'request-key-000009')}, headers: headers, as: :json
    assert_equal 422, response.status
    post '/mcp/oauth/revoke', params: {token: token, client_id: 'test-client'}
    get '/mcp/ais/identity', headers: headers
    assert_equal 401, response.status
  end

  def test_logged_in_oauth_consent_binds_user_and_returns_code_with_issuer
    sign_in @user
    get '/mcp/oauth/authorize', params: oauth_params
    assert_equal 200, response.status
    assert_includes response.body, 'Разрешить'
    post '/mcp/oauth/consent', params: {approve: 'yes'}
    assert_equal 302, response.status
    params = URI.decode_www_form(URI.parse(response.location).query).to_h
    assert_equal 'test-state', params['state']
    assert_equal 'https://ais.example', params['iss']
    assert McpCredential.lookup(params['code'], 'code')
    post '/mcp/oauth/consent', params: {approve: 'yes'}
    assert_equal 400, response.status
  end

  def test_thread_local_current_actor_and_restore_on_error
    before = User.current
    Thread.new { assert_nil User.current; User.current = :other; assert_equal :other, User.current }.join
    assert_equal before, User.current
    assert_raises(Mcp::Tools::Error) { tool('get_order', kind: 'invalid', id: 1) }
    assert_equal before, User.current
  end
  def test_concurrent_comment_retries_create_one_business_record
    actor_id = @user.id
    args = write_args
    # Rails test mode autoloads; production eager-loads. Warm dependencies before plain test threads.
    [Mcp::Tools, Mcp::Configuration, OrderPolicy, OrderNotePolicy, OrderNote, McpWrite, Audited.audit_class]
    results = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Mcp::Tools.new(User.find(actor_id), Mcp::Configuration::SCOPES).call('add_order_comment', args)
        end
      end
    end.map(&:value)
    assert_equal results.first.as_json, results.last.as_json
    assert_equal 1, @order.notes.count
    assert_equal 1, McpWrite.count
  end

  def test_oauth_consent_is_csrf_protected
    Mcp::OauthController.allow_forgery_protection = true
    sign_in @user
    get '/mcp/oauth/authorize', params: oauth_params
    assert_equal 200, response.status
    token = Nokogiri::HTML(response.body).at_css('input[name="authenticity_token"]')['value']
    assert_raises(ActionController::InvalidAuthenticityToken) { post '/mcp/oauth/consent', params: {approve: 'yes'} }
    post '/mcp/oauth/consent', params: {approve: 'yes', authenticity_token: token}
    assert_equal 302, response.status
  ensure
    Mcp::OauthController.allow_forgery_protection = false
  end

  def test_mcp_sdk_to_real_rails_http_end_to_end
    require 'rack/handler/webrick'
    require 'open3'
    require 'timeout'
    token = Mcp::Oauth.exchange(exchange(authorization_code))[:access_token]
    # The synthetic user requests revenue scope but real AIS policy denies it.
    McpCredential.lookup(token, 'access').update!(scope: 'ais:read ais:write ais:revenue')
    ready = Queue.new
    server = nil
    worker = Thread.new do
      Rack::Handler::WEBrick.run(Rails.application, Host: '127.0.0.1', Port: 0,
        AccessLog: [], Logger: WEBrick::Log.new(File::NULL)) do |instance|
        server = instance
        ready << instance.config[:Port]
      end
    end
    port = Timeout.timeout(10) { ready.pop }
    env = {'AIS_MCP_E2E_BACKEND' => "http://127.0.0.1:#{port}", 'AIS_MCP_E2E_TOKEN' => token}
    stdout, stderr, status = Timeout.timeout(30) do
      Open3.capture3(env, ENV.fetch('AIS_MCP_NODE_BIN', 'node'), Rails.root.join('integrations/chatgpt-mcp/test/e2e-client.js').to_s)
    end
    assert status.success?, stderr
    assert_equal "e2e_ok\n", stdout
    assert_equal 1, @order.notes.count
    assert_equal 'pending', @order.reload.status
  ensure
    server&.shutdown
    worker&.join(5)
  end

  def test_migration_rollback_and_reapply_preserves_existing_orders
    require_relative '../../db/migrate/20261005000000_create_mcp_credentials_and_writes'
    migration = CreateMcpCredentialsAndWrites.new
    migration.migrate(:down)
    refute ActiveRecord::Base.connection.table_exists?(:mcp_credentials)
    assert_equal 'N-1', @order.reload.number
    migration.migrate(:up)
    assert ActiveRecord::Base.connection.column_exists?(:mcp_credentials, :family_id)
    assert ActiveRecord::Base.connection.index_exists?(:mcp_writes, [:user_id, :request_key], unique: true)
    McpCredential.reset_column_information
    McpWrite.reset_column_information
  end

  def test_revenue_uses_existing_import_and_marks_incomplete_days
    @user.update_columns(role: 'superadmin')
    day = {'date' => '2026-10-01', 'revenue' => '125.50', 'cost' => '50.00',
      'gross_profit' => '75.50', 'cash' => '125.50', 'noncash' => '0', 'unallocated' => '0',
      'operation_count' => '1', 'quantity' => '1'}
    WeeklyMarkupImport.create!(delivery_id: 'a' * 64, period_from: '2026-10-01', period_to: '2026-10-01',
      calculated_at: Time.utc(2026, 10, 2), methodology_version: 'test-fixture', status: 'successful',
      payload: {'totals' => {'days' => [day]}, 'branches' => [{'warehouse_id' => 'test-warehouse', 'name' => 'Synthetic branch', 'days' => [day]}],
        'checks' => {'cost_data_complete' => true}, 'freshness' => {'incomplete_dates' => ['2026-10-01']},
        'discrepancies' => []})
    result = tool('revenue_summary', from: '2026-10-01', to: '2026-10-02')
    assert_equal '125.5', result[:totals][:revenue]
    assert_equal '125.5', result[:branches].first[:totals][:revenue]
    assert_equal ['2026-10-02'], result[:missing_dates]
    assert_equal ['2026-10-01'], result[:incomplete_dates]
    assert_equal ['2026-10-02'], result[:branches].first[:absent_dates]
    refute result[:complete]
  end

  def test_committed_outbox_failure_recovers_without_repeating_business_write
    reason = raw(RepairPauseReason, code: 'waiting_approval', name: 'Approval')
    args = {kind: 'service_job', id: @job.id, status: 'paused', expected_status: 'waiting', request_key: 'request-key-000010', pause_reason_id: reason.id, approval_question: 'Synthetic question'}
    SendApprovalTelegramNotificationJob.stubs(:perform_later).raises('Synthetic Redis failure')
    tool('change_order_status', args)
    assert_equal 1, @job.approval_requests.count
    assert_nil McpWrite.first.dispatched_at
    SendApprovalTelegramNotificationJob.unstub(:perform_later)
    tool('change_order_status', args)
    assert_equal 1, @job.approval_requests.count
    assert McpWrite.first.dispatched_at
  end

  def test_unexpected_ais_failure_is_sanitized_and_business_transaction_rolls_back
    token = Mcp::Oauth.exchange(exchange(authorization_code))[:access_token]
    OrderNote.any_instance.stubs(:save!).raises(StandardError, 'synthetic confidential upstream response')
    post '/mcp/ais/call', params: {tool: 'add_order_comment', arguments: write_args},
      headers: {'Authorization' => "Bearer #{token}"}, as: :json
    assert_equal 500, response.status
    assert_equal 'ais_error', JSON.parse(response.body).dig('error', 'code')
    refute_includes response.body, 'confidential'
    assert_equal 0, @order.notes.count
    assert_equal 0, McpWrite.count
  end

  def test_repair_busy_and_policy_guards
    tool('change_order_status', kind: 'service_job', id: @job.id, status: 'in_progress', expected_status: 'waiting', request_key: 'request-key-000011')
    other = raw(ServiceJob, ticket_number: 'N-2', client_id: @client.id, user_id: @user.id,
      department_id: @department.id, location_id: @location.id, repair_status_id: @waiting.id)
    assert_raises(Mcp::Tools::Error) do
      tool('change_order_status', kind: 'service_job', id: other.id, status: 'in_progress', expected_status: 'waiting', request_key: 'request-key-000012')
    end
    assert_equal @waiting.id, other.reload.repair_status_id
    nonrepair = raw(Location, name: 'Content', code: 'content', department_id: @department.id)
    @user.update_columns(role: 'programmer', location_id: nonrepair.id)
    assert_raises(Mcp::Tools::Error) { tool('get_order_statuses', kind: 'service_job', id: @job.id) }
  end

end
