module AuditReport
  class ActDefectCreateStrategy < TechnicianBaseStrategy
    def matches?(audit)
      audit.auditable_type == 'MovementItem' &&
        audit.action == 'create'
    end

    def action(audit)
      sp_name = audit.auditable.item.product.name
      sp_qty = audit.auditable.quantity
      "списал запчасть #{sp_name} (#{sp_qty} шт.)"
    end

    def link(audit)
      movement_act = audit.auditable.movement_act
      Rails.application.routes.url_helpers.movement_act_path(movement_act)
    end
  end
end
