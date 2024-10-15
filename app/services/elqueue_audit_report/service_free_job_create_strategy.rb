module ElqueueAuditReport
  class ServiceFreeJobCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'Service::FreeJob' &&
        audit.action == 'create'
    end

    def action(audit)
      "создал бесплатный сервис с задачей #{audit.auditable.task.name}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.service_free_job_path(audit.auditable)
    end
  end
end
