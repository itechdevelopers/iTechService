module AuditReport
  class ServiceJobCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'ServiceJob' &&
        audit.action == 'create'
    end

    def action(audit)
      "создал работу #{audit.auditable.ticket_number}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.service_job_path(audit.auditable)
    end
  end
end
