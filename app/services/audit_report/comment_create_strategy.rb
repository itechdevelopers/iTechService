module AuditReport
  class CommentCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'Comment' &&
        audit.action == 'create'
    end

    def action(audit)
      case audit.associated_type
      when 'QuickOrder'
        commentable = 'быстрому заказу'
        number = audit.associated.number_s
      when 'Kanban::Card'
        commentable = 'канбан карточке'
        number = audit.associated.name
      else
        commentable = ''
        number = ''
      end
      "создал комментарий к #{commentable} #{number}:
        #{audit.auditable.content}"
    end

    def link(audit)
      Rails.application.routes.url_helpers.polymorphic_path(audit.associated)
    end
  end
end
