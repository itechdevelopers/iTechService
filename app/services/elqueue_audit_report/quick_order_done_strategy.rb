module ElqueueAuditReport
  class QuickOrderDoneStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'QuickOrder' &&
        audit.action == 'update' &&
        audit.audited_changes.key?('is_done')
    end

    def action(audit)
      done_status = audit.audited_changes['is_done'][1] ? 'сделано' : 'не сделано'
      "поменял статус быстрого заказа №#{audit.auditable.number_s} на
        #{done_status}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.quick_order_path(audit.auditable)
    end
  end
end
