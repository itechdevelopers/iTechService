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
    context = Telephony::CallerContext.new(@user, '79991234567').call
    assert_equal 1, context[:clients].length
    assert_equal [], context[:clients].first[:entities]
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

end
