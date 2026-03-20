class SendKanbanTelegramNotificationJob < ApplicationJob
  queue_as :default

  def perform(card_id)
    card = Kanban::Card.find(card_id)
    board = card.board
    telegram_chat = board.telegram_chat
    return unless telegram_chat

    text = build_message(card, board)
    SendTelegramMessage.call(chat_id: telegram_chat.chat_id, text: text)
  end

  private

  def build_message(card, board)
    url = Rails.application.routes.url_helpers.kanban_card_url(card)

    <<~MSG.strip
      <b>#{board.name}</b>

      <b>Тема:</b> #{card.name}

      <b>Содержание:</b>
      #{card.content}

      <b>Автор:</b> #{card.author.short_name}
      <b>Дата:</b> #{card.created_at.strftime('%d.%m.%Y в %H:%M')}

      <a href="#{url}">Перейти на карточку</a>
    MSG
  end
end
