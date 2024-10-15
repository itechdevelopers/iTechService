module ElqueueAuditReport
  class KanbanCardCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'Kanban::Card' &&
        audit.action == 'create'
    end

    def action(audit)
      "создал канбан карточку #{audit.auditable.name} на доске
        #{audit.auditable.board.name}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.kanban_card_path(audit.auditable)
    end
  end
end
