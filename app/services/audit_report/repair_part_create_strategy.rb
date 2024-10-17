module AuditReport
  class RepairPartCreateStrategy < TechnicianBaseStrategy
    def matches?(audit)
      audit.auditable_type == 'RepairPart' &&
        audit.action == 'create'
    end

    def action(audit)
      repair_part_name = audit.auditable.item.product.name
      repair_part_qty = audit.auditable.quantity
      "поставил запчасть #{repair_part_name} (#{repair_part_qty} шт.)
        на ремонт"
    end

    def link(audit)
      service_job = audit.auditable.repair_task.service_job
      Rails.application.routes.url_helpers.service_job_path(service_job)
    end
  end
end
