# frozen_string_literal: true

# rubocop:disable Metrics

ActiveSupport::Dependencies.require_dependency 'kpi_audit/types'

module KpiAudit
  # Loads official KPI events and their queue evidence with bounded queries.
  class Collector
    attr_reader :department, :range

    def initialize(department:, date_from:, date_to:)
      @department = department
      @range = date_from.beginning_of_day..date_to.end_of_day
    end

    def call
      records = service_jobs.to_a + free_jobs.to_a + mac_tasks.to_a
      audit_map = create_audits(records)
      @video_diagnostics = video_diagnostics(audit_map.values)
      records.map { |record| build_event(record, audit_map[[record.class.base_class.name, record.id]]) }
    end

    private

    def service_jobs
      ServiceJob.where(department_id: department.id, created_at: range)
                .includes(:client, :item, sale: :payments)
    end

    def free_jobs
      Service::FreeJob.where(department_id: department.id, performed_at: range)
                      .includes(:client, :receiver, :performer, :task)
    end

    def mac_tasks
      DeviceTask.joins(:task, :service_job)
                .where(service_jobs: { department_id: department.id }, tasks: { code: 'mac' }, done_at: range)
                .includes(:performer, :task, service_job: [:client, :item, { sale: :payments }])
    end

    def create_audits(records)
      records.group_by { |record| record.class.base_class.name }.each_with_object({}) do |(type, typed), result|
        Audited::Audit.where(auditable_type: type, auditable_id: typed.map(&:id), action: 'create')
                      .order(:id).find_each do |audit|
          next unless audit.metadata.to_h['audit_type'] == 'elqueue_work'

          result[[type, audit.auditable_id]] = audit
        end
      end
    end

    def build_event(record, audit)
      job = record.is_a?(DeviceTask) ? record.service_job : (record if record.is_a?(ServiceJob))
      Event.new(
        kind: event_kind(record), record: record, employee_id: employee_id(record),
        client: record.respond_to?(:client) ? record.client : job&.client,
        client_id: record.respond_to?(:client_id) ? record.client_id : job&.client_id,
        department_id: department.id, occurred_at: event_time(record),
        ticket_id: audit&.metadata.to_h&.dig('ticket_id')&.to_i,
        serial: normalize(job&.serial_number), imei: normalize(job&.imei),
        device_id: job&.item_id, service_job_id: job&.id,
        operation_key: operation_key(record), monetary_amount: monetary_amount(job),
        url: record_url(record), video_diagnostic: video_diagnostic(audit),
        audit_id: audit&.id, audit_request_uuid: audit&.request_uuid,
        audit_metadata_confirmed: audit&.metadata.to_h&.dig('audit_type') == 'elqueue_work',
        ticket_snapshot: ticket_snapshot(audit), economic_sources: economic_sources(record, job)
      )
    end

    def event_kind(record)
      return :free_job if record.is_a?(Service::FreeJob)
      return :mac if record.is_a?(DeviceTask)

      :service_job
    end

    def employee_id(record)
      return record.receiver_id if record.is_a?(Service::FreeJob)
      return record.performer_id if record.is_a?(DeviceTask)

      record.user_id
    end

    def event_time(record)
      return record.performed_at if record.is_a?(Service::FreeJob)
      return record.done_at if record.is_a?(DeviceTask)

      record.created_at
    end

    def operation_key(record)
      return "free:#{record.task_id}:#{record.comment.to_s.squish.downcase}" if record.is_a?(Service::FreeJob)
      return "mac:#{record.task_id}" if record.is_a?(DeviceTask)

      "service_job:#{record.type_of_work.to_s.squish.downcase}"
    end

    def monetary_amount(job)
      sale = job&.sale
      return 0.to_d unless sale&.status == 1 && !sale.is_return?

      sale.payments.sum(&:value).to_d
    end

    def normalize(value)
      value.to_s.gsub(/\s+/, '').presence
    end

    def record_url(record)
      helpers = Rails.application.routes.url_helpers
      options = Rails.application.routes.default_url_options.merge(only_path: false)
      return helpers.service_free_job_url(record, options) if record.is_a?(Service::FreeJob)

      helpers.service_job_url(record.is_a?(DeviceTask) ? record.service_job : record, options)
    rescue ActionController::UrlGenerationError
      nil
    end

    def sale_url(sale)
      Rails.application.routes.url_helpers.sale_url(
        sale, Rails.application.routes.default_url_options.merge(only_path: false)
      )
    rescue ActionController::UrlGenerationError
      nil
    end

    def economic_sources(record, job)
      sale = job&.sale
      return [] unless sale

      related = ["#{event_kind(record)}:#{record.id}"]
      [{ sale: { id: sale.id, status: sale.status, posted: sale.status == 1,
                 return_sale: sale.is_return?, occurred_at: sale.date || sale.created_at, url: sale_url(sale) },
         payments: sale.payments.map do |payment|
           { id: payment.id, sale_id: sale.id, value: payment.value.to_d, kind: payment.kind,
             occurred_at: payment.created_at, related_kpi: related }
         end,
         related_kpi: related }]
    end

    def ticket_snapshot(audit)
      diagnostic = video_diagnostic(audit).to_h
      ticket = diagnostic[:waiting_client]
      call = diagnostic[:called]
      return nil unless ticket

      { id: ticket.id, number: ticket.ticket_number, issued_at: ticket.ticket_issued_at,
        served_at: ticket.ticket_served_at, queue_key: ticket.electronic_queue.ipad_link,
        queue_name: ticket.electronic_queue.queue_name, called_id: call&.id, called_at: call&.created_at,
        window_number: call&.elqueue_window&.window_number,
        historical_employee: employee_snapshot(call&.user) }.freeze
    end

    def employee_snapshot(user)
      return nil unless user

      { id: user.id, full_name: user.full_name, login: user.username }.freeze
    end

    def video_diagnostic(audit)
      return { status: 'NO_TICKET' } unless audit

      @video_diagnostics.fetch(audit.id, status: 'UNRESOLVED')
    end

    def video_diagnostics(audits)
      eligible = audits.filter_map do |audit|
        ticket_id = audit.metadata.to_h['ticket_id'].to_i
        [audit, ticket_id] if ticket_id.positive?
      end
      return {} if eligible.empty?

      ticket_ids = eligible.map(&:last).uniq
      tickets = WaitingClient.unscoped.where(id: ticket_ids).includes(queue_item: :electronic_queue).index_by(&:id)
      calls = ElqueueTicketMovement::Called.where(waiting_client_id: ticket_ids)
                                           .includes(:elqueue_window, :electronic_queue, :user)
                                           .order(created_at: :desc, id: :desc)
                                           .group_by(&:waiting_client_id)
      eligible.each_with_object({}) do |(audit, ticket_id), result|
        ticket = tickets[ticket_id]
        preceding = calls.fetch(ticket_id, []).select { |call| call.created_at <= audit.created_at }
        call = preceding.find { |candidate| candidate.user_id == audit.user_id }
        status = if call
                   video_status(ticket, call)
                 elsif preceding.any?
                   video_status(ticket, preceding.first, status: 'USER_MISMATCH')
                 else
                   { status: 'NO_CALLED' }
                 end
        result[audit.id] = status
      end
    end

    def video_status(ticket, call, status: 'EXACT')
      return { status: 'NO_TICKET' } unless ticket
      return { status: 'USER_MISMATCH' } unless call
      return { status: 'NO_WINDOW' } unless call.elqueue_window

      Hikvision::CameraRouter.for(queue: ticket.electronic_queue.ipad_link,
                                  window: call.elqueue_window.window_number)
      { status: status, waiting_client: ticket, called: call }
    rescue Hikvision::CameraCatalog::Error
      { status: 'UNSUPPORTED_QUEUE' }
    end
  end
end
# rubocop:enable Metrics
