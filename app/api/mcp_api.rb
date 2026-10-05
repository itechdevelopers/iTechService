# frozen_string_literal: true
# rubocop:disable all

require 'digest'

class McpApi < Grape::API
  version 'v1', using: :path
  format :json
  before { authenticate! }

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
    def idempotent!(operation)
      key = params[:idempotency_key].to_s
      error!({ error: 'idempotency_key is required for write operations' }, 422) if key.blank?
      digest = Digest::SHA256.hexdigest(params.to_h.deep_stringify_keys.except('idempotency_key').to_json)
      old = McpIdempotencyKey.find_by(user_id: current_user.id, operation: operation, key: key)
      if old && old.payload_digest != digest
        error!({ error: 'idempotency_key was already used with a different payload' }, 409)
      end
      return JSON.parse(old.response_json) if old
      result = yield
      McpIdempotencyKey.create!(user: current_user, operation: operation, key: key,
                                payload_digest: digest, response_json: result.to_json)
      result
    rescue ActiveRecord::RecordNotUnique
      JSON.parse(McpIdempotencyKey.find_by!(user_id: current_user.id, operation: operation, key: key).response_json)
    end
    def item_payload(item)
      { id: item.id, name: item.name, code: item.code, barcode: item.barcode_num, serial_number: item.serial_number,
        imei: item.imei, client_ids: item.service_jobs.where.not(client_id: nil).distinct.pluck(:client_id) }
    end
    def job_payload(job)
      { id: job.id, ticket: job.ticket_number, status: job.status, client_id: job.client_id, item_id: job.item_id,
        serial_number: job.serial_number, imei: job.imei, department: job.department && { id: job.department.id, name: job.department.name },
        created_at: job.created_at&.iso8601, notes: job.device_notes.oldest_first.limit(50).map { |n| note_payload(n) } }
    end
    def note_payload(note); { id: note.id, content: note.content, user_id: note.user_id, created_at: note.created_at&.iso8601 }; end
    def client_payload(client)
      { id: client.id, name: client.full_name, phone: client.full_phone_number, email: client.email,
        department: client.department && { id: client.department.id, name: client.department.name },
        devices: client.devices.limit(20).map { |i| item_payload(i) }, service_jobs: client.service_jobs.newest.limit(20).map { |j| job_payload(j) } }
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
  end

  namespace 'clients' do
    get :search do
      q = params[:query].to_s.strip; error!({ error: 'query is required' }, 422) if q.blank?
      { clients: policy_scope(Client.search(client_q: q)).limit(limit).map { |c| client_payload(c) } }
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
          { success: true, device_id: params[:id].to_i, service_job_id: job.id, note_id: note.id, content: note.content }
        end
      end
    end
  end

  namespace 'requests' do
    get :search do
      authorize :read, ServiceJob; q = params[:query].to_s.strip; error!({ error: 'query is required' }, 422) if q.blank?
      { requests: policy_scope(ServiceJob.search(ticket: q, service_job: q, client: q)).limit(limit).map { |j| job_payload(j) } }
    end
    route_param :id, type: Integer do
      get { job_payload(find_record!(ServiceJob, params[:id])) }
      post :notes do
        job = find_record!(ServiceJob, params[:id]); content = params[:content].to_s.strip; error!({ error: 'content is required' }, 422) if content.blank?
        idempotent!('add_request_note') do
          note = job.device_notes.build(content: content, user: current_user)
          authorize :create, note
          error!({ error: note.errors.full_messages }, 422) unless note.save
          { success: true, request_id: job.id, note_id: note.id, content: note.content }
        end
      end
    end
  end

  namespace 'client_requests' do
    get :search do
      authorize :read, ClientRequest; scope = policy_scope(ClientRequest).recent
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
      get { request_payload(find_record!(ClientRequest, params[:id])) }
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

  namespace 'employees' do
    get :search do
      q = params[:query].to_s.strip; error!({ error: 'query is required' }, 422) if q.blank?
      { employees: User.search(name: q).limit(limit).map { |u| user_payload(u) } }
    end
    get ':id/merits_faults' do
      user = User.find(params[:id]); authorize :read, Merit.new(recipient: user); authorize :read, Fault.new(causer: user)
      { employee: user_payload(user), merits: Merit.by_recipient(user.id).ordered.limit(limit).map { |m| { id: m.id, comment: m.comment, date: m.date&.iso8601 } },
        faults: Fault.by_causer(user.id).ordered.limit(limit).map { |f| { id: f.id, kind_id: f.kind_id, comment: f.comment, date: f.date&.iso8601, penalty: f.penalty } } }
    end
    get :fault_kinds do
      authorize :read, FaultKind; { fault_kinds: FaultKind.ordered.map { |k| { id: k.id, name: k.name, description: k.description, financial: k.financial? } } }
    end
    post ':id/merits' do
      user = User.find(params[:id])
      idempotent!('add_merit') do
        result = Merit::Create.call({ user_id: user.id, merit: { comment: params[:comment], date: params[:date] } }, current_user: current_user)
        error!({ error: 'merit could not be created' }, 422) unless result.success?; merit = result['model'] || result[:model]
        { success: true, merit: { id: merit.id, recipient_id: merit.recipient_id, comment: merit.comment, date: merit.date&.iso8601 } }
      end
    end
    post ':id/faults' do
      user = User.find(params[:id])
      idempotent!('add_fault') do
        result = Fault::Create.call({ user_id: user.id, fault: { comment: params[:comment], date: params[:date], kind_id: params[:kind_id], issued_by_id: current_user.id } }, current_user: current_user)
        error!({ error: 'fault could not be created' }, 422) unless result.success?; fault = result['model'] || result[:model]
        { success: true, fault: { id: fault.id, causer_id: fault.causer_id, kind_id: fault.kind_id, comment: fault.comment, date: fault.date&.iso8601, penalty: fault.penalty } }
      end
    end
  end
end
