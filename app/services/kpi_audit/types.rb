# frozen_string_literal: true

# rubocop:disable Metrics

module KpiAudit
  Event = Struct.new(
    :kind, :record, :employee_id, :client_id, :client, :department_id, :occurred_at,
    :ticket_id, :waiting_client, :serial, :imei, :device_id, :service_job_id,
    :operation_key, :monetary_amount, :url, :video_diagnostic,
    :audit_id, :audit_request_uuid, :audit_metadata_confirmed,
    :ticket_snapshot, :economic_sources,
    keyword_init: true
  ) do
    def id
      record.id
    end

    def strong_keys
      keys = []
      keys << "ticket:#{ticket_id}" if ticket_id
      keys << "service_job:#{service_job_id}" if service_job_id
      keys << "device:#{device_id}" if device_id
      keys << "serial:#{serial.to_s.downcase}" if serial.present?
      keys << "imei:#{imei.to_s.downcase}" if imei.present?
      keys
    end
  end

  Visit = Struct.new(:id, :events, :confidence, :evidence, keyword_init: true) do
    delegate :first, :last, to: :events
    def started_at
      events.map(&:occurred_at).min
    end

    def ended_at
      events.map(&:occurred_at).max
    end

    def employee_ids
      events.map(&:employee_id).compact.uniq
    end

    def client_ids
      events.map(&:client_id).compact.uniq
    end

    def kpi_count
      events.size
    end

    def kinds
      events.map(&:kind)
    end

    def confirmed?
      confidence == :strong
    end
  end

  Reason = Struct.new(:code, :text, :points, :family, keyword_init: true)

  Anomaly = Struct.new(
    :type, :score, :reasons, :evidence, :started_at, :ended_at, :events,
    :client, :ticket, :window, :monetary_result, :video_context_available,
    keyword_init: true
  ) do
    def download_video(**options)
      event = events.find { |item| item.video_diagnostic.to_h[:status] == 'EXACT' }
      raise QueueVideoContext::Error, 'Video context is unavailable' unless event

      SuspiciousEvent.new(subject: event.record).download_video(**options)
    end
  end

  EmployeeResult = Struct.new(
    :id, :full_name, :login, :risk_score, :risk_level, :statistics, :anomalies,
    keyword_init: true
  )

  Analysis = Struct.new(
    :department, :date_from, :date_to, :mode, :employees, :investigations, :statistics, :metadata,
    keyword_init: true
  )
end
# rubocop:enable Metrics
