class KanbanMailer < ApplicationMailer
  def new_card_notification(manager_ids, card_id)
    @managers = User.where(id: manager_ids)
    @card = Kanban::Card.find(card_id)
    @card_author = @card.author
    @board = @card.board
    manager_emails = @managers.pluck(:email).compact
    return unless manager_emails.any?

    mail to: manager_emails, subject: "Новая карточка на канбан доске #{@board.name}"
  end
end
