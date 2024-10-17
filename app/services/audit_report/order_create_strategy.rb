module AuditReport
  class OrderCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'Order' &&
        audit.action == 'create'
    end

    def action(audit)
      "создал заказ #{audit.auditable.number}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.order_path(audit.auditable)
    end
  end
end
