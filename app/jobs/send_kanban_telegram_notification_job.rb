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
      <b>#{esc(board.name)}</b>

      <b>Тема:</b> #{esc(card.name)}

      <b>Содержание:</b>
      #{esc(card.content)}

      <b>Автор:</b> #{esc(card.author.short_name)}
      <b>Дата:</b> #{card.created_at.strftime('%d.%m.%Y в %H:%M')}#{deadline_line(card)}

      <a href="#{url}">Перейти на карточку</a>
    MSG
  end

  def deadline_line(card)
    return unless card.deadline

    "\n      <b>Дедлайн:</b> #{card.deadline.strftime('%d.%m.%Y')}"
  end

  def esc(text)
    CGI.escapeHTML(text.to_s)
  end
end
