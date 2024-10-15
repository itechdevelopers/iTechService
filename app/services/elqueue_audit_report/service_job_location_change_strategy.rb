module ElqueueAuditReport
  class ServiceJobLocationChangeStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'ServiceJob' &&
        audit.action == 'update' &&
        audit.audited_changes.key?('location_id')
    end

    def action(audit)
      service_job = audit.auditable
      old_location, new_location = audit.audited_changes['location_id']
      "переместил работу #{service_job.ticket_number} c локации #{Location.find(old_location).name}
        на локацию #{Location.find(new_location).name}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.service_job_path(audit.auditable)
    end
  end
end
