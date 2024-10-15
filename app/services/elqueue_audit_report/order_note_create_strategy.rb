module ElqueueAuditReport
  class OrderNoteCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'OrderNote' &&
        audit.action == 'create'
    end

    def action(audit)
      "создал комментарий к заказу #{audit.associated.number}:
        #{audit.auditable.content}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.order_path(audit.associated)
    end
  end
end
