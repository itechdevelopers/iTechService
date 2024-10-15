module ElqueueAuditReport
  class ServiceJobCommentStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'DeviceNote' &&
        audit.action == 'create'
    end

    def action(audit)
      "добавил комментарий к работе #{audit.associated.ticket_number}:
        #{audit.auditable.content}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.service_job_path(audit.associated)
    end
  end
end
