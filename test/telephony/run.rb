# Run against a dedicated empty database named ais_telephony_test. The legacy
# repository Selenium helper is incompatible with its pinned Selenium version;
# these tests use Rails directly and never load that browser helper.
ENV['RAILS_ENV'] ||= 'development'
require_relative '../../config/environment'
require 'minitest/autorun'
require 'rack/test'
require 'warden/test/helpers'
abort 'Use the dedicated ais_telephony_test database' unless ActiveRecord::Base.connection.current_database == 'ais_telephony_test'

class TelephonyTest < Minitest::Test
  include Rack::Test::Methods
  include Warden::Test::Helpers
  def app; Rails.application; end

  def insert(model, attrs)
    connection = model.connection
    attrs = attrs.merge(created_at: Time.current, updated_at: Time.current).select { |key, _| model.column_names.include?(key.to_s) }
    columns = attrs.keys.map { |key| connection.quote_column_name(key) }.join(',')
    values = attrs.values.map { |value| connection.quote(value) }.join(',')
    id = connection.select_value("INSERT INTO #{connection.quote_table_name(model.table_name)} (#{columns}) VALUES (#{values}) RETURNING id")
    model.find(id)
  end

  def setup
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
    ENV['TELEPHONY_ENABLED'] = 'true'
    ENV['TELEPHONY_SHARED_SECRET'] = 't' * 48
    ENV['TELEPHONY_INGEST_SECRET'] = 'i' * 48
    city = insert(City, name: 'Тест', time_zone: 'Vladivostok')
    brand = insert(Brand, name: 'Тест')
    @department = insert(Department, name: 'Тест', city_id: city.id, brand_id: brand.id, role: 1, code: 'telephony-test')
    @user = insert(User, username: 'telephony-test', name: 'Тест', surname: 'Первый', role: 'software', department_id: @department.id, telephony_extension: '7771', pbx_extension: '101', encrypted_password: Devise::Encryptor.digest(User, 'Phone-test-pass1'), email: 'phone@example.test')
    insert(UserSettings, user_id: @user.id)
    @ability = Ability.find_by!(name: 'work_with_telephony')
    @user.abilities << @ability
    User.current = @user
  end

  def teardown
    User.current = nil
    ActiveRecord::Base.connection.rollback_transaction
    %w[TELEPHONY_ENABLED TELEPHONY_SHARED_SECRET TELEPHONY_INGEST_SECRET].each { |key| ENV.delete(key) }
    Warden.test_reset!
    clear_cookies
  end

  def login
    post '/users/sign_in', user: { login: @user.username, password: 'Phone-test-pass1' }
    assert_equal 302, last_response.status
  end

  def call_attrs(uid = '1791417600.123')
    { 'call_unique_id' => uid, 'started_at' => Time.current.iso8601, 'caller_number' => 'влд +7 (999) 123-45-67', 'called_number' => '101', 'answered_extension' => '7771', 'direction' => 'incoming', 'status' => 'answered', 'duration' => 14, 'billsec' => 10 }
  end

  def test_number_normalization_preserves_internal_and_rejects_labels
    assert_equal '79991234567', Telephony::Number.normalize('влд +7 (999) 123-45-67')
    assert_equal '79991234567', Telephony::Number.normalize('САКХ_89991234567')
    assert_equal '79991234567', Telephony::Number.normalize('7 999 123 45 67')
    %w[VDK SAH USS USSF KHD HAB vdk sah uss ussf khd hab].each do |prefix|
      assert_equal '79146896537', Telephony::Number.normalize(prefix + '79146896537')
      assert_equal '79146896537', Telephony::Number.normalize(prefix + ': +7 (914) 689-65-37')
    end
    assert_equal '79146896537', Telephony::Number.normalize('vdk: +7 (914) 689-65-37')
    assert_nil Telephony::Number.normalize('101')
    assert_nil Telephony::Number.normalize('unknown-79991234567')
    assert_nil Telephony::Number.dialable('7;System(rm)')
    assert_equal '101', Telephony::Number.dialable('101')
  end

  def test_permission_needs_ability_assignment_active_user_and_feature_flag
    assert TelephonyPolicy.new(@user, :telephony).use?
    @user.telephony_extension = nil
    refute TelephonyPolicy.new(@user, :telephony).use?
    @user.telephony_extension = '7771'; @user.is_fired = true
    refute TelephonyPolicy.new(@user, :telephony).use?
    @user.is_fired = false; @user.abilities.delete(@ability)
    refute TelephonyPolicy.new(@user, :telephony).use?
    @user.abilities << @ability; ENV['TELEPHONY_ENABLED'] = 'false'
    refute TelephonyPolicy.new(@user, :telephony).use?
  end

  def test_extension_range_and_database_uniqueness
    @user.telephony_extension = '7781'; @user.valid?
    assert @user.errors[:telephony_extension].any?
    @user.telephony_extension = '7780'; @user.pbx_extension = '7772'; @user.valid?
    assert @user.errors[:pbx_extension].any?
    assert_raises ActiveRecord::RecordNotUnique do
      ActiveRecord::Base.transaction(requires_new: true) { insert(User, username: 'duplicate', role: 'software', department_id: @department.id, telephony_extension: '7771') }
    end
  end

  def test_import_is_idempotent_and_employee_snapshot_survives_reassignment
    record = Telephony::ImportCall.call(call_attrs)
    assert_equal '79991234567', record.caller_number
    assert_equal @user.id, record.answered_user_id
    original_name = record.answered_employee_name
    @user.update_columns(telephony_extension: nil)
    other = insert(User, username: 'other', surname: 'Второй', name: 'Тест', role: 'software', department_id: @department.id, telephony_extension: '7771')
    record = Telephony::ImportCall.call(call_attrs)
    assert_equal 1, PhoneCall.count
    assert_equal @user.id, record.answered_user_id
    assert_equal original_name, record.answered_employee_name
    refute_equal other.id, record.answered_user_id
  end

  def test_physical_phone_attribution_and_audio_permissions
    record = Telephony::ImportCall.call(call_attrs.merge('answered_extension' => '101'))
    assert_equal @user.id, record.answered_user_id
    assert PhoneCallPolicy.new(@user, record).audio?
    other = insert(User, username: 'other', role: 'software', department_id: @department.id)
    other.abilities << @ability
    refute PhoneCallPolicy.new(other, record).audio?
    other.abilities << Ability.create!(name: 'listen_all_transcriptions')
    assert PhoneCallPolicy.new(other, record).audio?
  end

  def test_caller_context_prioritizes_active_device_orders_and_repairs
    client = insert(Client, name: 'Иван', surname: 'Тестовый', full_phone_number: '79991234567', phone_number: '9991234567', department_id: @department.id)
    insert(Order, customer_id: client.id, customer_type: 'Client', department_id: @department.id, object_kind: 'device', object: 'iPhone', status: 'current', number: 'PHONE-1')
    insert(Order, customer_id: client.id, customer_type: 'Client', department_id: @department.id, object_kind: 'device', object: 'Old', status: 'archive', number: 'PHONE-2')
    location = insert(Location, name: 'Ремонт', code: 'repair', department_id: @department.id)
    insert(ServiceJob, client_id: client.id, department_id: @department.id, location_id: location.id)
    insert(QuickOrder, client_id: client.id, department_id: @department.id, user_id: @user.id, number: 7, device_kind: 'iPhone', is_done: false)
    insert(QuickOrder, client_id: client.id, department_id: @department.id, user_id: @user.id, number: 8, device_kind: 'iPad', is_done: true)
    context = Telephony::CallerContext.new(@user, 'сакх79991234567').call
    assert_equal 1, context[:clients].length
    assert_equal %w[order service_job quick_order], context[:clients].first[:entities].map { |e| e[:kind] }
    assert_equal [], Telephony::CallerContext.new(@user, '79990000000').call[:clients]
  end

  def test_unknown_and_completed_client_context
    client = insert(Client, name: 'Иван', surname: 'Тестовый', full_phone_number: '79991234567', phone_number: '9991234567', department_id: @department.id)
    insert(Order, customer_id: client.id, customer_type: 'Client', department_id: @department.id, object_kind: 'device', object: 'Old', status: 'archive', number: 'PHONE-2')
    context = Telephony::CallerContext.new(@user, 'VDK79991234567').call
    assert_equal 1, context[:clients].length
    assert_equal [], context[:clients].first[:entities]
    assert_equal '/clients/' + client.id.to_s, context[:clients].first[:url]
    login_as(@user, scope: :user)
    %w[VDK SAH USS USSF KHD HAB].each do |prefix|
      get '/telephony/caller', number: prefix + '79991234567'
      assert_equal 200, last_response.status
      assert_equal client.id.to_s, JSON.parse(last_response.body)['clients'].first['url'].split('/').last
    end
  end

  def test_signed_ingestion_and_invalid_signature
    body = JSON.generate(calls: [call_attrs])
    stamp = Time.now.to_i.to_s
    signature = OpenSSL::HMAC.hexdigest('SHA256', ENV['TELEPHONY_INGEST_SECRET'], stamp + '.' + body)
    post '/api/v1/telephony/calls', body, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_AIS_TIMESTAMP' => stamp, 'HTTP_X_AIS_SIGNATURE' => signature
    assert_equal 200, last_response.status, last_response.body
    assert_equal 1, PhoneCall.count
    post '/api/v1/telephony/calls', body, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_AIS_TIMESTAMP' => stamp, 'HTTP_X_AIS_SIGNATURE' => 'a' * 64
    assert_equal 401, last_response.status
  end

  def test_unreviewed_feature_stays_disabled
    ENV.delete('TELEPHONY_ENABLED')
    refute TelephonyPolicy.new(@user, :telephony).use?
  end

  def test_recording_path_traversal_is_rejected
    assert_raises ActiveRecord::RecordInvalid do
      Telephony::ImportCall.call(call_attrs.merge('recording_path' => '/var/spool/asterisk/monitor/../private.wav'))
    end
  end

  def test_pagination_is_one_hundred
    105.times { |i| Telephony::ImportCall.call(call_attrs("1791417600.#{i}")) }
    page = PhoneCall.newest.page(1).per(100)
    assert_equal 100, page.size
    assert_equal 5, PhoneCall.newest.page(2).per(100).size
  end
  def test_phone_page_and_ticket_are_authorized_by_current_employee
    login_as(@user, scope: :user)
    get '/telephony'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Телефон · 7771'
    csrf = last_response.body[/name="csrf-token" content="([^"]+)"/, 1]
    post '/telephony/ticket', {}, 'HTTP_X_CSRF_TOKEN' => csrf, 'HTTP_ACCEPT' => 'application/json'
    assert_equal 200, last_response.status, last_response.body
    response = JSON.parse(last_response.body)
    encoded, signature = response['ticket'].split('.')
    assert_equal OpenSSL::HMAC.hexdigest('SHA256', ENV['TELEPHONY_SHARED_SECRET'], encoded), signature
    claims = JSON.parse(Base64.urlsafe_decode64(encoded))
    assert_equal @user.id, claims['user_id']
    assert_equal '7771', claims['extension']
    assert_equal 60, claims['exp'] - claims['iat']
    @user.abilities.delete(@ability)
    post '/telephony/ticket', {}, 'HTTP_X_CSRF_TOKEN' => csrf, 'HTTP_ACCEPT' => 'application/json'
    assert_equal 302, last_response.status
  end

  def test_workspace_retains_phone_and_rejects_external_or_recursive_paths
    login_as(@user, scope: :user)
    get '/telephony/workspace', path: '/clients?search=test'
    assert_equal 200, last_response.status
    assert_equal 'no-store', last_response.headers['Cache-Control']
    assert_includes last_response.body, 'src="/clients?search=test"'
    assert_includes last_response.body, 'id="ais-workspace-phone"'
    assert_includes last_response.body, 'allow="microphone; autoplay"'
    assert_includes last_response.body, 'Телефония · 7771'
    if ENV['AIS_PHONE_BROWSER_FIXTURES']
      File.write(File.join(ENV.fetch('AIS_PHONE_BROWSER_FIXTURES'), 'workspace.html'), last_response.body)
      get '/telephony', embedded: '1'
      assert_equal 200, last_response.status
      assert_includes last_response.body, 'class="embedded"'
      File.write(File.join(ENV.fetch('AIS_PHONE_BROWSER_FIXTURES'), 'phone.html'), last_response.body)
    end
    ['https://example.test', '//example.test', '/\\example.test', '/telephony/workspace', "/clients\n", "x\n/clients", "https://example.test\n/clients", "javascript:alert(1)//\n/clients", "/\t/example.test", '/telephony#x', '/x/../telephony/workspace', '/./telephony/workspace', '/telephony.html?embedded=1', '/%74elephony/workspace', '/x/%2e%2e/telephony/workspace'].each do |path|
      get '/telephony/workspace', path: path
      assert_equal 200, last_response.status
      assert_includes last_response.body, 'title="Рабочее место АИС" src="/"'
    end
    @user.abilities.delete(@ability)
    get '/telephony/workspace'
    assert_equal 302, last_response.status
  end

  def test_phone_directory_uses_existing_labels_and_requires_telephony_access
    PhoneLabel.create!(phone_number: '105', label: 'Бармены', group_name: 'Океанский 90')
    login_as(@user, scope: :user)
    get '/telephony/directory'
    assert_equal 200, last_response.status
    assert_equal 'no-store', last_response.headers['Cache-Control']
    entry = JSON.parse(last_response.body)['entries'].find { |e| e['number'] == '105' }
    assert_equal 'Бармены', entry['label']
    assert_equal 'Океанский 90', entry['group']
    get '/telephony/caller', number: '105'
    context = JSON.parse(last_response.body)
    assert_equal '105', context['number']
    assert_equal 'Бармены', context['directory']['label']
    assert_equal [], context['clients']
    @user.abilities.delete(@ability)
    get '/telephony/directory'
    assert_equal 302, last_response.status
  end

  def test_regular_employee_cannot_assign_telephony_numbers
    controller = UsersController.new
    controller.define_singleton_method(:current_user) { @test_user }
    controller.instance_variable_set(:@test_user, @user)
    controller.instance_variable_set(:@user, @user)
    params = ActionController::Parameters.new(telephony_extension: '7772', pbx_extension: '102')
    controller.send(:filter_ability_ids_for_limited_rights, params)
    refute params.key?(:telephony_extension)
    refute params.key?(:pbx_extension)
    @user.role = 'admin'
    params = ActionController::Parameters.new(telephony_extension: '7772', pbx_extension: '102')
    controller.send(:filter_ability_ids_for_limited_rights, params)
    assert_equal '7772', params[:telephony_extension]
  end

  def test_bad_batch_is_atomic_and_old_signature_is_rejected
    bad = call_attrs('1791417600.124').merge('status' => 'invented')
    body = JSON.generate(calls: [call_attrs, bad])
    stamp = Time.now.to_i.to_s
    signature = OpenSSL::HMAC.hexdigest('SHA256', ENV['TELEPHONY_INGEST_SECRET'], stamp + '.' + body)
    post '/api/v1/telephony/calls', body, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_AIS_TIMESTAMP' => stamp, 'HTTP_X_AIS_SIGNATURE' => signature
    assert_equal 422, last_response.status
    assert_equal 0, PhoneCall.count
    stamp = (Time.now.to_i - 600).to_s
    signature = OpenSSL::HMAC.hexdigest('SHA256', ENV['TELEPHONY_INGEST_SECRET'], stamp + '.' + body)
    post '/api/v1/telephony/calls', body, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_AIS_TIMESTAMP' => stamp, 'HTTP_X_AIS_SIGNATURE' => signature
    assert_equal 401, last_response.status
  end

  def test_history_renders_at_most_one_hundred_calls
    login_as(@user, scope: :user)
    105.times { |i| Telephony::ImportCall.call(call_attrs("1791417600.#{i}")) }
    get '/phone_calls', per: 1000
    assert_equal 200, last_response.status, last_response.body[0,300]
    assert_equal 100, last_response.body.scan('79991234567').length
  end

  def test_outgoing_call_tracks_caller_employee
    record = Telephony::ImportCall.call(call_attrs.merge('caller_number' => '7771', 'called_number' => '79990000000', 'answered_extension' => '79990000000', 'direction' => 'outgoing'))
    assert_equal @user.id, record.caller_user_id
    assert_equal @user.full_name, record.caller_employee_name
    assert_nil record.answered_user_id
    assert_equal '79990000000', record.answered_extension
  end

  def test_audio_range_and_malformed_range_without_sftp
    record = Telephony::ImportCall.call(call_attrs.merge('recording_path' => '/var/spool/asterisk/monitor/2026/10/08/test.wav'))
    cache = Rails.root.join('tmp', 'audio_cache', Digest::SHA256.hexdigest(record.recording_path) + '.wav')
    FileUtils.mkdir_p(cache.dirname);File.binwrite(cache, '0123456789')
    login_as(@user, scope: :user)
    get "/phone_calls/#{record.id}/audio", {}, 'HTTP_RANGE' => 'bytes=2-5'
    assert_equal 206, last_response.status
    assert_equal '2345', last_response.body
    assert_equal 'bytes 2-5/10', last_response.headers['Content-Range']
    get "/phone_calls/#{record.id}/audio", {}, 'HTTP_RANGE' => 'broken'
    assert_equal 416, last_response.status
  ensure
    File.delete(cache) if cache && File.exist?(cache)
  end

  def test_live_call_updates_stale_events_and_final_cdr
    live = call_attrs.merge('source' => 'ami', 'status' => 'ringing', 'observed_at' => Time.current.iso8601(6), 'answered_extension' => nil, 'legs' => [{ 'unique_id' => '1791417600.123', 'number' => '101', 'state' => 'ringing' }])
    record = Telephony::ImportCall.call(live)
    assert_equal 'ringing', record.status
    Telephony::ImportCall.call(live.merge('status' => 'talking', 'observed_at' => (Time.current - 10).iso8601(6)))
    assert_equal 'ringing', record.reload.status
    Telephony::ImportCall.call(call_attrs)
    assert record.reload.finalized_at
    Telephony::ImportCall.call(live.merge('observed_at' => (Time.current + 1).iso8601(6)))
    assert_equal 'answered', record.reload.status
  end

  def test_cdr_child_enriches_one_logical_call
    live = call_attrs.merge('source' => 'ami', 'status' => 'talking', 'observed_at' => Time.current.iso8601(6), 'legs' => [{ 'unique_id' => '1791417600.124', 'number' => '101', 'state' => 'talking' }])
    record = Telephony::ImportCall.call(live)
    Telephony::ImportCall.call(call_attrs('1791417600.124'))
    assert_equal 1, PhoneCall.count
    assert_equal 'answered', record.reload.status
  end

  def test_history_fragment_and_signed_sync_heartbeat
    login_as(@user, scope: :user)
    get '/phone_calls', fragment: '1'
    assert_equal 200, last_response.status
    refute_includes last_response.body, '<html'
    body = JSON.generate(calls: [], health: { source: 'ami', connected: true, observed_at: Time.current.iso8601 })
    stamp = Time.now.to_i.to_s
    signature = OpenSSL::HMAC.hexdigest('SHA256', ENV['TELEPHONY_INGEST_SECRET'], stamp + '.' + body)
    post '/api/v1/telephony/calls', body, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_AIS_TIMESTAMP' => stamp, 'HTTP_X_AIS_SIGNATURE' => signature
    assert_equal 200, last_response.status
    assert TelephonySyncState.find_by!(source: 'ami').connected
  end

  def test_live_merge_retires_only_provisional_rows
    stamp = Time.current.iso8601(6)
    child = call_attrs('1791417600.124').merge('source' => 'ami', 'status' => 'ringing', 'observed_at' => stamp, 'legs' => [{ 'unique_id' => '1791417600.124', 'number' => '101', 'state' => 'ringing' }])
    Telephony::ImportCall.call(child)
    parent = call_attrs.merge('source' => 'ami', 'status' => 'ringing', 'observed_at' => stamp, 'supersedes' => ['1791417600.124'], 'legs' => child['legs'])
    Telephony::ImportCall.call(parent)
    assert_equal 1, PhoneCall.count
    assert_nil PhoneCall.find_by(call_unique_id: '1791417600.124')
    Telephony::ImportCall.call(call_attrs('1791417600.125'))
    Telephony::ImportCall.call(parent.merge('observed_at' => (Time.current + 1).iso8601(6), 'supersedes' => ['1791417600.125']))
    assert_equal 2, PhoneCall.count
    assert PhoneCall.find_by!(call_unique_id: '1791417600.125').finalized_at
  end

  def test_history_links_legacy_client_on_outgoing_call
    client = insert(Client, name: 'Иван', surname: 'Тестовый', phone_number: '9991234567', department_id: @department.id)
    Telephony::ImportCall.call(call_attrs.merge('caller_number' => '101', 'called_number' => '79991234567', 'direction' => 'outgoing'))
    login_as(@user, scope: :user)
    get '/phone_calls'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "href=\"/clients/#{client.id}\""
  end

  def test_external_status_dates_and_directory_filters
    @user.update_columns(role: 'admin')
    label = PhoneLabel.create!(phone_number: '101', label: 'Продажи', group_name: 'Продажи', department_id: @department.id, user_id: @user.id)
    Telephony::ImportCall.call(call_attrs)
    Telephony::ImportCall.call(call_attrs('1791417600.125').merge('caller_number' => '102', 'called_number' => '103', 'direction' => 'internal', 'answered_extension' => '103'))
    login_as(@user, scope: :user)
    get '/phone_calls', external_only: '1', group_name: 'Продажи', directory_id: label.id, department_id: @department.id, date_from: Date.current.iso8601, date_to: Date.current.iso8601
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'label label-info'
    assert_equal 1, last_response.body.scan('79991234567').length
    get '/phone_calls', status: 'missed'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Вызовов пока нет'
  end

  def test_directory_admin_management_and_employee_denial
    assert TelephonyDirectoryPolicy.new(@user, :telephony_directory).index?
    refute TelephonyDirectoryPolicy.new(@user, :telephony_directory).manage?
    login_as(@user, scope: :user)
    post '/telephony_directory', phone_label: { phone_number: '101', label: 'Недопустимо' }
    assert_equal 302, last_response.status
    assert_equal 0, PhoneLabel.count
    @user.update_columns(role: 'admin')
    login_as(@user, scope: :user)
    get '/telephony_directory'
    assert_equal 200, last_response.status
    csrf = last_response.body[/name="csrf-token" content="([^"]+)"/, 1]
    post '/telephony_directory', { phone_label: { phone_number: '101', label: 'Ремонт', department_id: @department.id, user_id: @user.id } }, 'HTTP_X_CSRF_TOKEN' => csrf
    assert_equal 302, last_response.status
    record = PhoneLabel.find_by!(phone_number: '101')
    patch "/telephony_directory/#{record.id}", { phone_label: { phone_number: '101', label: 'Сервис' } }, 'HTTP_X_CSRF_TOKEN' => csrf
    assert_equal 'Сервис', record.reload.label
    get '/telephony_directory'
    assert_equal 200, last_response.status
    delete "/telephony_directory/#{record.id}", {}, 'HTTP_X_CSRF_TOKEN' => csrf
    assert_equal 0, PhoneLabel.count
  end

  def test_directory_assignment_is_snapshotted_for_future_calls
    @user.update_columns(pbx_extension: nil)
    label = PhoneLabel.create!(phone_number: '101', label: 'Сервис', user_id: @user.id)
    record = Telephony::ImportCall.call(call_attrs.merge('answered_extension' => '101'))
    assert_equal @user.id, record.answered_user_id
    label.update!(user_id: nil)
    Telephony::ImportCall.call(call_attrs.merge('answered_extension' => '101'))
    assert_equal @user.id, record.reload.answered_user_id
  end

  def test_directory_filter_includes_unanswered_group_participant
    label = PhoneLabel.create!(phone_number: '101', label: 'Общая линия отдела', department_id: @department.id)
    Telephony::ImportCall.call(call_attrs.merge('source' => 'ami', 'status' => 'ringing', 'called_number' => '600', 'answered_extension' => nil, 'observed_at' => Time.current.iso8601(6), 'legs' => [{ 'unique_id' => '1791417600.124', 'number' => '101', 'state' => 'ringing' }]))
    login_as(@user, scope: :user)
    get '/phone_calls', directory_id: label.id
    assert_equal 200, last_response.status
    assert_equal 1, last_response.body.scan('79991234567').length
    assert_includes last_response.body, 'Участники'
  end

  def test_profile_ownership_takes_priority_over_directory_caption
    other = insert(User, username: 'directory-owner', name: 'Другой', surname: 'Сотрудник', role: 'software', department_id: @department.id)
    PhoneLabel.create!(phone_number: '7771', label: 'Подпись линии', user_id: other.id)
    call = Telephony::ImportCall.call(call_attrs)
    assert_equal @user.id, call.answered_user_id
  end

  def test_recording_link_and_player_preserve_permissions
    record = Telephony::ImportCall.call(call_attrs.merge('recording_path' => '/var/spool/asterisk/monitor/2026/10/12/test.wav'))
    login_as(@user, scope: :user)
    get '/phone_calls'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'preload="none"'
    assert_includes last_response.body, "data-call-recording=\"#{record.id}\""
    other = insert(User, username: 'audio-reader', name: 'Другой', role: 'software', department_id: @department.id)
    insert(UserSettings, user_id: other.id)
    other.abilities << @ability
    login_as(other, scope: :user)
    get '/phone_calls'
    assert_equal 200, last_response.status
    refute_includes last_response.body, "data-call-recording=\"#{record.id}\""
  end

end
