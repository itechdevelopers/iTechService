module AuditReport
  class SparePartDefectCreateStrategy < TechnicianBaseStrategy
    def matches?(audit)
      audit.auditable_type == 'SparePartDefect' &&
        audit.action == 'create'
    end

    def action(audit)
      sp_name = audit.auditable.item.product.name
      sp_qty = audit.auditable.qty
      "списал запчасть #{sp_name} (#{sp_qty} шт.) при ремонте"
    end

    def link(audit)
      service_job = audit.auditable.repair_part.repair_task.service_job
      Rails.application.routes.url_helpers.service_job_path(service_job)
    end
  end
end
