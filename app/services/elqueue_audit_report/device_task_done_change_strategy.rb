module ElqueueAuditReport
  class DeviceTaskDoneChangeStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'DeviceTask' &&
        audit.action == 'update' &&
        audit.audited_changes.key?('done')
    end

    def action(audit)
      done_status = audit.audited_changes['done'][1]
      done = done_status == 1 ? 'выполненную' : 'не выполненную'
      "отметил задачу #{audit.auditable.task.name} у работы
        #{audit.associated.ticket_number} как #{done}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.service_job_path(audit.associated)
    end
  end
end
