# frozen_string_literal: true

# Живая лента одного диалога: сообщение, пришедшее от клиента или отправленное
# другим сотрудником, появляется без перезагрузки страницы.
class ClientConversationChannel < ApplicationCable::Channel
  def self.stream_name(conversation_id)
    "client_conversation_#{conversation_id}"
  end

  # Шлём и id, и готовый HTML: по id браузер понимает, не его ли это
  # собственная реплика (её уже дорисовал ответ на форму) и не пора ли
  # заменить «[фото загружается…]» на саму картинку.
  def self.broadcast_message(message)
    html = ApplicationController.render(
      partial: 'client_conversations/message',
      locals: { message: message }
    )
    ActionCable.server.broadcast(stream_name(message.client_conversation_id),
                                 id: message.id, html: html)
  end

  def subscribed
    conversation = ClientConversation.find_by(id: params[:id])
    # Доступ к переписке клиентов — тот же, что к странице: канал обходит
    # контроллер, и без проверки любой залогиненный мог бы слушать чужой чат.
    return reject if conversation.nil? || !allowed?

    stream_from self.class.stream_name(conversation.id)
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def allowed?
    ClientConversationPolicy.new(current_user, ClientConversation).show?
  end
end
