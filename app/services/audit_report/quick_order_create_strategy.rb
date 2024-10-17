module AuditReport
  class QuickOrderCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'QuickOrder' &&
        audit.action == 'create'
    end

    def action(audit)
      "создал быстрый заказ №#{audit.auditable.number_s}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.quick_order_path(audit.auditable)
    end
  end
end
