# frozen_string_literal: true

# Рассылка колокольчиков о новом сообщении клиента. Вынесена из обработчика,
# потому что масштабируется числом сотрудников локации Медиа: на каждого —
# запись в базу, рендер партиала и публикация в ActionCable.
class NotifyClientConversationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ClientMessage.find_by(id: message_id)
    return if message.nil?

    message.conversation.notify_new_message(message)
  end
end
