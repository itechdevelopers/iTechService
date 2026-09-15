# frozen_string_literal: true

# Сигнал «число диалогов без ответа изменилось».
#
# Вещаем именно сигнал, а не само число: счёт у каждого свой — по его городу, —
# поэтому значение считает сервер в ответ на запрос браузера. Тот же приём, что
# у колокольчика уведомлений: авторитетное состояние знает только сервер.
class ClientConversationCounterChannel < ApplicationCable::Channel
  STREAM = 'client_conversations_counter'

  def self.ping
    ActionCable.server.broadcast(STREAM, {})
  end

  def subscribed
    # Канал идёт мимо контроллера, поэтому доступ проверяем здесь — иначе
    # любой залогиненный узнавал бы о движении в чужой переписке.
    return reject unless ClientConversationPolicy.new(current_user, ClientConversation).index?

    stream_from STREAM
  end

  def unsubscribed
    stop_all_streams
  end
end
