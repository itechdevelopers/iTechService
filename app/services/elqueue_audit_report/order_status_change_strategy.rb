module ElqueueAuditReport
  class OrderStatusChangeStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'Order' &&
        audit.action == 'update' &&
        audit.audited_changes.key?('status')
    end

    def action(audit)
      new_status = I18n.t("orders.statuses.#{audit.audited_changes['status'][1]}")
      "поменял статус заказа #{audit.auditable.number} на
        #{new_status}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.order_path(audit.auditable)
    end
  end
end
