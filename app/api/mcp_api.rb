# frozen_string_literal: true
# rubocop:disable all

require 'digest'

class McpApi < Grape::API
  version 'v1', using: :path
  format :json
  before do
    authenticate!
    @mcp_previous_time_zone = Time.zone
    Time.zone = current_user.time_zone.presence || Rails.application.config.time_zone
  end
  finally { Time.zone = @mcp_previous_time_zone if @mcp_previous_time_zone }

  rescue_from Pundit::NotAuthorizedError do
    error!({ error: 'You are not allowed to perform this operation.' }, 403)
  end

  rescue_from ActiveRecord::RecordNotFound do
    error!({ error: 'Record not found.' }, 404)
  end

  helpers do
    CLIENT_FIELDS = %w[name surname patronymic email contact_phone admin_info].freeze
    ITEM_FIELDS = %w[barcode_num].freeze
    def limit; [[params[:limit].to_i, 1].max, 50].min; end
    def find_record!(klass, id, action = :read)
      record = klass.find(id)
      authorize action, record
    end
    def policy_scope(scope)
      Pundit.policy_scope!(current_user, scope)
    end
    def current_user
      token = auth_token_from_headers
      @current_user ||= if token.to_s.start_with?('mcp_')
                          McpApiToken.authenticate(token)
                        elsif token.present?
                          User.where(is_fired: [false, nil], authentication_token: token).first
                        end
      User.current = @current_user
      @current_user
    end
    def idempotent!(operation)
      key = params[:idempotency_key].to_s
      error!({ error: 'idempotency_key is required for write operations' }, 422) if key.blank?
      error!({ error: 'idempotency_key is too long' }, 422) if key.length > 200
      digest = Digest::SHA256.hexdigest(params.to_h.deep_stringify_keys.except('idempotency_key').to_json)
      lock_id = Digest::SHA256.hexdigest([current_user.id, operation, key].to_json)[0, 16].to_i(16)
      lock_id -= 2**64 if lock_id >= 2**63
      failure = nil
      result = McpIdempotencyKey.transaction do
        # Transaction-scoped lock serializes retries across Rails processes.
        McpIdempotencyKey.connection.execute("SELECT pg_advisory_xact_lock(#{lock_id})")
        caught = catch(:error) do
          old = McpIdempotencyKey.find_by(user_id: current_user.id, operation: operation, key: key)
          error!({ error: 'idempotency_key was already used with a different payload' }, 409) if old && old.payload_digest != digest
          if old
            [:completed, JSON.parse(old.response_json)]
          else
            entry = McpIdempotencyKey.create!(user: current_user, operation: operation, key: key,
                                             payload_digest: digest, response_json: '{}')
            value = yield
            entry.update!(response_json: value.to_json)
            [:completed, value]
          end
        end
        if caught.is_a?(Array) && caught.first == :completed
          caught.last
        else
          failure = caught
          raise ActiveRecord::Rollback
        end
      end
      throw :error, failure if failure
      result
    rescue ActiveRecord::RecordInvalid => exception
      error!({ error: exception.record.errors.full_messages }, 422)
    end
    def business_time!(value)
      text = value.to_s
      begin
        if /\A\d{4}-\d{2}-\d{2}\z/.match?(text)
          date = Date.iso8601(text)
          return Time.zone.local(date.year, date.month, date.day)
        end
        raise ArgumentError unless /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?\z/.match?(text)
        DateTime.iso8601(text)
        hour, minute, second = text[11, 8].split(':').map(&:to_i)
        raise ArgumentError if hour > 23 || minute > 59 || second > 59
        Time.zone.parse(text)
      rescue ArgumentError
        error!({ error: 'from and to must be valid ISO dates or timestamps' }, 422)
      end
    end
    def time_range!(default_from = nil, default_to = nil)
      from = params[:from].present? ? business_time!(params[:from]) : default_from
      to = params[:to].present? ? business_time!(params[:to]) : default_to
      error!({ error: 'to must be after from' }, 422) if from && to && to <= from
      [from, to]
    end
    def item_payload(item)
      { id: item.id, name: item.name, code: item.code, barcode: item.barcode_num, serial_number: item.serial_number,
        imei: item.imei, client_ids: item.service_jobs.map(&:client_id).compact.uniq }
    end
    def job_payload(job, include_notes: true)
      { id: job.id, ticket: job.ticket_number, status: job.status, client_id: job.client_id, item_id: job.item_id,
        serial_number: job.serial_number, imei: job.imei, department: job.department && { id: job.department.id, name: job.department.name },
        created_at: job.created_at&.iso8601, notes: include_notes ? job.device_notes.oldest_first.limit(50).map { |n| note_payload(n) } : nil }
    end
    def note_payload(note); { id: note.id, content: note.content, user_id: note.user_id, created_at: note.created_at&.iso8601 }; end
    def client_summary(client)
      { id: client.id, name: client.full_name, phone: client.full_phone_number, email: client.email,
        department: client.department && { id: client.department.id, name: client.department.name } }
    end
    def client_payload(client)
      devices = client.devices.includes(:product, :features, :service_jobs).limit(20)
      jobs = client.service_jobs.includes(:item, :features, :department).newest.limit(20)
      client_summary(client).merge(devices: devices.map { |i| item_payload(i) },
                                   service_jobs: jobs.map { |j| job_payload(j, include_notes: false) })
    end
    def request_payload(request)
      { id: request.id, kind: request.kind, status: request.status, purchase_check_status: request.purchase_check_status,
        client_id: request.client_id, item_id: request.item_id, reason: request.reason, archived: request.archived, created_at: request.created_at&.iso8601 }
    end
    def user_payload(user)
      { id: user.id, name: user.full_name, username: user.username, department: user.department && { id: user.department.id, name: user.department.name } }
    end
    def update_allowed!(record, fields, action = :update)
      authorize action, record
      attrs = params.slice(*fields).to_h.symbolize_keys
      error!({ error: 'at least one allowed field is required', allowed: fields }, 422) if attrs.empty?
      error!({ error: record.errors.full_messages }, 422) unless record.update(attrs)
      record
    end

    def department_for!(requested_id = nil)
      department_id = requested_id.presence || current_user.department_id
      allowed = current_user.superadmin? || current_user.able_to?(:access_all_departments) || department_id.to_i == current_user.department_id
      error!({ error: 'department is outside your access scope' }, 403) unless allowed
      Department.find(department_id)
    end

    def unlock_access!(request)
      allowed = current_user.superadmin? || request.department_id == current_user.department_id
      error!({ error: 'You are not allowed to access this request.' }, 403) unless allowed
      request
    end

    def unlock_payload(request, include_comments: true)
      {
        id: request.id, status: request.status, status_options: DeviceUnlockRequest.statuses.keys,
        reason: request.reason, created_at: request.created_at&.iso8601,
        client: { id: request.client_id, name: request.client.full_name },
        device: { id: request.item_id, name: request.item.name, serial_number: request.item.serial_number, imei: request.item.imei },
        department: { id: request.department_id, name: request.department.name },
        comments: include_comments ? request.comments.newest.limit(50).map { |comment| { id: comment.id, content: comment.content, user_id: comment.user_id, created_at: comment.created_at&.iso8601 } } : nil
      }
    end

    def repair_option_payload(service, product, department)
      can_view_cost = Pundit.policy!(current_user, Product).view_purchase_price?
      price = service.price(department)
      parts = service.spare_parts.includes(:product).map do |part|
        purchase_price = can_view_cost ? part.product&.purchase_price : nil
        { id: part.id, product_id: part.product_id, name: part.product&.name, description: part.product&.comment,
          quantity: part.quantity, purchase_price: purchase_price, purchase_price_source: 'Product#purchase_price' }
      end
      { repair_service_id: service.id, repair_name: service.name, model: product.name, model_id: product.id,
        part_variants: parts, client_price: price&.shown_price, client_price_value: price&.value,
        client_price_range: price && price.is_range_price? ? { from: price.value_from, to: price.value_to } : nil,
        cost: can_view_cost && parts.all? { |part| !part[:purchase_price].nil? } ? parts.sum { |part| part[:purchase_price].to_d * part[:quantity].to_i } : nil,
        cost_visibility: can_view_cost ? 'permitted' : 'hidden_by_permissions',
        cost_definition: 'Сумма текущих Product#purchase_price по настроенным запчастям с учётом quantity; это не скидка и не автоматически чистая прибыль.',
        time: { standard: service.time_standard, from: service.time_standard_from, to: service.time_standard_to, repair_time: service.repair_time, unit: 'minutes unless the service configuration says otherwise' },
        technical_notes: [service.client_info, service.special_marks].compact.reject(&:blank?), availability: service.remnants_s(department.spare_parts_store), price_updated_at: price&.updated_at&.iso8601 }
    end
  end

  namespace 'products' do
    get :cost_by_barcode do
      # The employee's existing sensitive product-price permission is checked
      # before starting the connector; the shared 1C identity grants no AIS rights.
      authorize :view_purchase_price, Product
      arguments = params.slice('barcode', 'product_id', 'characteristic_id', 'package_id',
                               'organization_id', 'warehouse_id', 'party_id', 'as_of').to_h
      begin
        OneCProductCost.call(arguments)
      rescue OneCProductCost::InvalidArguments => exception
        error!({ error: exception.message }, 422)
      rescue OneCProductCost::Unavailable
        error!({ error: 'Чтение 1С недоступно или результат неполный; стоимость не определена.' }, 502)
      end
    end
  end

  namespace 'clients' do
    get :search do
      q = params[:query].to_s.strip; error!({ error: 'query is required' }, 422) if q.blank?
      { clients: policy_scope(Client.search(client_q: q)).includes(:department).limit(limit).map { |c| client_summary(c) } }
    end
    route_param :id, type: Integer do
      get { client_payload(find_record!(Client, params[:id])) }
      patch { idempotent!('update_client') { client_payload(update_allowed!(find_record!(Client, params[:id]), CLIENT_FIELDS)) } }
      post :notes do
        client = find_record!(Client, params[:id], :update); content = params[:content].to_s.strip
        error!({ error: 'content is required' }, 422) if content.blank?
        idempotent!('add_client_note') do
          note = client.comments.build(content: content, user: current_user)
          authorize :create, note
          error!({ error: note.errors.full_messages }, 422) unless note.save
          { success: true, client_id: client.id, comment_id: note.id, content: note.content }
        end
      end
    end
  end

  namespace 'devices' do
    get :search do
      q = params[:query].to_s.strip; error!({ error: 'query is required' }, 422) if q.blank?
      { devices: policy_scope(Item.search(q: q)).limit(limit).map { |i| item_payload(i) } }
    end
    route_param :id, type: Integer do
      get { item_payload(find_record!(Item, params[:id])) }
      patch { idempotent!('update_device') { item_payload(update_allowed!(find_record!(Item, params[:id]), ITEM_FIELDS, :modify)) } }
      post :notes do
        job = ServiceJob.where(item_id: params[:id]).order(created_at: :desc).first
        error!({ error: 'a service job is required to store a device note' }, 422) unless job
        authorize :read, job; content = params[:content].to_s.strip; error!({ error: 'content is required' }, 422) if content.blank?
        idempotent!('add_device_note') do
          note = job.device_notes.build(content: content, user: current_user)
          authorize :create, note
          error!({ error: note.errors.full_messages }, 422) unless note.save
          Service::DeviceSubscribersNotificationJob.perform_later(job.id, current_user.id, { device_note: { content: note.content } })
          { success: true, device_id: params[:id].to_i, service_job_id: job.id, note_id: note.id, content: note.content }
        end
      end
    end
  end

  namespace 'requests' do
    get :search do
      authorize :read, ServiceJob; q = params[:query].to_s.strip; error!({ error: 'query is required' }, 422) if q.blank?
      { requests: policy_scope(ServiceJob.where(id: ServiceJob.search(ticket: q).select(:id))).or(
          policy_scope(ServiceJob.where(id: ServiceJob.search(service_job: q).left_outer_joins(:features).select('service_jobs.id')))).or(
          policy_scope(ServiceJob.where(id: ServiceJob.search(client: q).select(:id)))).newest.limit(limit).map { |j| job_payload(j) } }
    end
    route_param :id, type: Integer do
      get { job_payload(find_record!(ServiceJob, params[:id])) }
      post :notes do
        job = find_record!(ServiceJob, params[:id]); content = params[:content].to_s.strip; error!({ error: 'content is required' }, 422) if content.blank?
        idempotent!('add_request_note') do
          note = job.device_notes.build(content: content, user: current_user)
          authorize :create, note
          error!({ error: note.errors.full_messages }, 422) unless note.save
          Service::DeviceSubscribersNotificationJob.perform_later(job.id, current_user.id, { device_note: { content: note.content } })
          { success: true, request_id: job.id, note_id: note.id, content: note.content }
        end
      end
    end
  end

  namespace 'client_requests' do
    get :search do
      authorize :index, ClientRequest; scope = policy_scope(ClientRequest).recent
      scope = scope.where(id: params[:id]) if params[:id].present?; scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
      { requests: scope.limit(limit).map { |r| request_payload(r) } }
    end
    post do
      authorize :create, ClientRequest; client = Client.find(params[:client_id]); item = Item.find(params[:item_id])
      error!({ error: 'client and device are not linked by an existing service job' }, 422) unless client.service_jobs.where(item_id: item.id).exists?
      idempotent!('create_client_request') do
        request = ClientRequest.new(client: client, item: item, reason: params[:reason].to_s); request.user = current_user; request.department = current_user.department
        error!({ error: request.errors.full_messages }, 422) unless request.save
        { success: true, request: request_payload(request) }
      end
    end
    route_param :id, type: Integer do
      get { request_payload(find_record!(ClientRequest, params[:id], :show)) }
      patch :status do
        request = find_record!(ClientRequest, params[:id], :update_status); status = params[:status].to_s
        error!({ error: 'unknown status', allowed: ClientRequest.statuses.keys }, 422) unless ClientRequest.statuses.key?(status)
        idempotent!('update_client_request_status') do
          error!({ error: request.errors.full_messages }, 422) unless request.update(status: status)
          { success: true, request: request_payload(request) }
        end
      end
    end
  end

  namespace 'repairs' do
    get :options do
      department = department_for!(params[:department_id])
      model_query = params[:model_query].to_s.strip
      error!({ error: 'model_query is required' }, 422) if model_query.blank?
      products = Product.search(query: model_query).not_archived.limit(limit)
      repair_query = params[:repair_query].to_s.strip
      options = products.flat_map do |product|
        services = product.repair_services.not_archived
        services = services.where('repair_services.name ILIKE ?', "%#{repair_query}%") if repair_query.present?
        services.map do |service|
          authorize :read, service
          repair_option_payload(service, product, department)
        end
      end
      { models: products.map { |product| { id: product.id, name: product.name } }, options: options }
    end
  end

  namespace 'unlock_requests' do
    get :statuses do
      { statuses: DeviceUnlockRequest.statuses.keys.map { |key| { key: key, label: key } }, actions: %w[show update_status add_comment] }
    end

    get :search do
      scope = DeviceUnlockRequest.active.includes(:client, :item, :department)
      scope = scope.where(status: params[:status]) if params[:status].present? && DeviceUnlockRequest.statuses.key?(params[:status].to_s)
      scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
      scope = scope.where(item_id: params[:device_id]) if params[:device_id].present?
      from, to = time_range!
      scope = scope.where('device_unlock_requests.created_at >= ?', from) if from
      scope = scope.where('device_unlock_requests.created_at < ?', to) if to
      scope = scope.where(department_id: current_user.department_id) unless current_user.superadmin?
      { requests: scope.recent.limit(limit).map { |request| unlock_payload(request, include_comments: false) } }
    end

    route_param :id, type: Integer do
      get { unlock_payload(unlock_access!(DeviceUnlockRequest.includes(:client, :item, :department).find(params[:id]))) }

      patch :status do
        request = unlock_access!(DeviceUnlockRequest.find(params[:id])); status = params[:status].to_s
        error!({ error: 'unknown status', allowed: DeviceUnlockRequest.statuses.keys }, 422) unless DeviceUnlockRequest.statuses.key?(status)
        idempotent!('update_unlock_request_status') do
          error!({ error: request.errors.full_messages }, 422) unless request.update(status: status)
          request.notify_status_change
          { success: true, request: unlock_payload(request.reload) }
        end
      end

      post :comments do
        request = unlock_access!(DeviceUnlockRequest.find(params[:id])); content = params[:content].to_s.strip
        error!({ error: 'content is required' }, 422) if content.blank?
        idempotent!('add_unlock_request_comment') do
          comment = request.comments.build(content: content, user: current_user)
          error!({ error: comment.errors.full_messages }, 422) unless comment.save
          request.notify_new_comment
          { success: true, request_id: request.id, comment_id: comment.id, content: comment.content }
        end
      end
    end
  end

  namespace 'reports' do
    get :catalog do
      authorize :index, :report
      cards = current_user.superadmin? ? ReportCard.includes(:report_column).all : current_user.accessible_report_cards.includes(:report_column)
      { reports: cards.map { |card| { id: card.id, key: card.content, annotation: card.annotation, column: card.report_column&.name, class_name: "#{card.content.to_s.camelize}Report" } } }
    end

    get :electronic_queue do
      authorize :index, :report
      department = department_for!(params[:department_id])
      begin
        start_date = Date.iso8601(params[:from].to_s)
        end_date = Date.iso8601(params[:to].to_s)
      rescue ArgumentError
        error!({ error: 'from and to must be ISO dates' }, 422)
      end
      error!({ error: 'to must not be before from' }, 422) if end_date < start_date
      report = ElqueueTicketsReport.new(start_date: start_date.iso8601, end_date: end_date.iso8601,
                                        department_id: department.id, start_time: params[:start_time].presence || '00:00',
                                        end_time: params[:end_time].presence || '23:59')
      report.call
      { report: report.result, source: 'ElqueueTicketsReport', timezone: Time.zone.name, limitations: ['Показатели отражают только события, сохранённые электронной очередью; интерпретация качества сотрудника не является частью отчёта.'] }
    end
  end

  namespace 'equipment_orders' do
    get :search do
      authorize :read, Order
      scope = current_user.superadmin? || current_user.able_to?(:access_all_departments) ? Order.all : Order.where(department_id: current_user.department_id)
      scope = scope.where(object_kind: 'device')
      from, to = time_range!
      scope = scope.where('orders.created_at >= ?', from) if from
      scope = scope.where('orders.created_at < ?', to) if to
      scope = scope.where(status: params[:status]) if params[:status].present? && Order::STATUSES.include?(params[:status].to_s)
      scope = scope.where('orders.number LIKE ?', "%#{params[:number]}%") if params[:number].present?
      orders = scope.includes(:department, :customer).order(created_at: :desc).limit(limit)
      { orders: orders.map { |order| { id: order.id, number: order.number, model: order.model, object: order.object, quantity: order.quantity, status: order.status, created_at: order.created_at&.iso8601, desired_date: order.desired_date&.iso8601, department: order.department_name, customer: order.customer_type == 'Client' ? { id: order.customer_id, name: order.customer&.full_name } : nil } }, statuses: Order::STATUSES }
    end

    get :summary do
      authorize :read, Order
      scope = current_user.superadmin? || current_user.able_to?(:access_all_departments) ? Order.all : Order.where(department_id: current_user.department_id)
      scope = scope.where(object_kind: 'device')
      from, to = time_range!(1.year.ago.beginning_of_day, Time.current)
      grouped = scope.where(created_at: from...to).group(:model, :status).sum(:quantity)
      { from: from.iso8601, to: to.iso8601, by_model_and_status: grouped.map { |(model, status), quantity| { model: model, status: status, units: quantity } }, definition: 'units — сумма поля Order#quantity, а не число заявок; даты — created_at; это заказы техники, не подтверждённые продажи.' }
    end
  end

  namespace 'employees' do
    get :search do
      q = params[:query].to_s.strip; error!({ error: 'query is required' }, 422) if q.blank?
      { employees: User.search(name: q).limit(limit).map { |u| user_payload(u) } }
    end
    get ':id/merits_faults' do
      user = User.find(params[:id])
      error!({ error: 'You are not allowed to perform this operation.' }, 403) unless current_user.any_admin? || current_user.id == user.id
      { employee: user_payload(user), merits: Merit.by_recipient(user.id).ordered.limit(limit).map { |m| { id: m.id, comment: m.comment, date: m.date&.iso8601 } },
        faults: Fault.by_causer(user.id).ordered.limit(limit).map { |f| { id: f.id, kind_id: f.kind_id, comment: f.comment, date: f.date&.iso8601, penalty: f.penalty } } }
    end
    get :fault_kinds do
      authorize :read, FaultKind; { fault_kinds: FaultKind.ordered.map { |k| { id: k.id, name: k.name, description: k.description, financial: k.financial? } } }
    end
    post ':id/merits' do
      user = User.find(params[:id])
      idempotent!('add_merit') do
        result = Merit::Create.({ user_id: user.id, merit: { comment: params[:comment], date: params[:date].presence || Date.current.iso8601 } }, 'current_user' => current_user)
        error!({ error: 'You are not allowed to perform this operation.' }, 403) if result['result.policy.default']&.failure?
        error!({ error: result['contract.default']&.errors&.full_messages }, 422) unless result.success?; merit = result['model'] || result[:model]
        { success: true, merit: { id: merit.id, recipient_id: merit.recipient_id, comment: merit.comment, date: merit.date&.iso8601 } }
      end
    end
    post ':id/faults' do
      user = User.find(params[:id])
      idempotent!('add_fault') do
        result = Fault::Create.({ user_id: user.id, fault: { comment: params[:comment], date: params[:date].presence || Date.current.iso8601, kind_id: params[:kind_id], issued_by_id: current_user.id } }, 'current_user' => current_user)
        error!({ error: 'You are not allowed to perform this operation.' }, 403) if result['result.policy.default']&.failure?
        error!({ error: result['contract.default']&.errors&.full_messages }, 422) unless result.success?; fault = result['model'] || result[:model]
        { success: true, fault: { id: fault.id, causer_id: fault.causer_id, kind_id: fault.kind_id, comment: fault.comment, date: fault.date&.iso8601, penalty: fault.penalty } }
      end
    end
  end
end
