module ElqueueAuditReport
  class DeviceTaskCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'DeviceTask' &&
        audit.action == 'create'
    end

    def action(audit)
      "создал задачу #{audit.auditable.task.name} к работе
        #{audit.associated.ticket_number}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.service_job_path(audit.associated)
    end
  end
end
