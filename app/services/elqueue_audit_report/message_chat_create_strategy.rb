module ElqueueAuditReport
  class MessageChatCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'Message' &&
        audit.action == 'create'
    end

    def action(_audit)
      'добавил сообщение в чат'
    end

    def link(audit)
      Rails.application.routes.url_helpers.messages_path
    end
  end
end
