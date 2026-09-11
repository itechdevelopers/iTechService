# frozen_string_literal: true

require 'tempfile'

# Доставка ответа сотрудника клиенту. Отдельно от SendTelegramMessageJob:
# там адресат — чат по chat_id и терять нечего, кроме уведомления, а здесь у
# сообщения есть строка в БД, которую сотрудник видит в ленте, и она обязана
# честно показывать, ушло оно или нет.
#
# Отправляем фоном, потому что запрос к api.telegram.org непредсказуем по
# времени: синхронная отправка держала бы форму ответа открытой всё это время.
class SendClientMessageJob < ApplicationJob
  queue_as :default

  SendTelegramMessage::TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 4 do |job, error|
      # error_label, а не error.message: на Rails 5.1 сюда приходит КЛАСС
      # исключения (см. ApplicationJob#error_label).
      label = job.send(:error_label, error)
      Rails.logger.error("[SendClientMessageJob] giving up for message #{job.arguments.first}: #{label}")
      # Помечаем провал в самой записи: сотрудник должен увидеть в ленте, что
      # клиент ответа не получил, иначе он будет ждать реакции на сообщение,
      # которого не было.
      ClientMessage.find_by(id: job.arguments.first)
                   &.update(delivery_status: 'failed', delivery_error: label)
    end
  end

  def perform(message_id)
    message = ClientMessage.find_by(id: message_id)
    return if message.nil? || message.delivery_status == 'sent'

    outcome = message.photo? ? deliver_photo(message) : deliver_text(message)

    if outcome.success?
      message.update!(delivery_status: 'sent', sent_at: Time.current)
    elsif SendTelegramMessage.transient_error?(outcome.error)
      # Отказы самого Telegram (клиент заблокировал бота, чат удалён)
      # постоянны — повторять их четыре раза бессмысленно.
      raise outcome.error
    else
      message.update!(delivery_status: 'failed', delivery_error: outcome.result)
    end
  end

  private

  def deliver_text(message)
    SendTelegramMessage.call(chat_id: chat_id_for(message), text: message.body,
                             bot: :client, parse_mode: nil)
  end

  # Файл лежит в облаке, а гем принимает открытый File — поэтому сначала
  # выкачиваем во временный. Ссылкой не отдаём: бакет приватный, и полагаться
  # на то, что Telegram до него дотянется, нельзя.
  def deliver_photo(message)
    tempfile = Tempfile.new(['client_out', File.extname(message.photo.path.to_s).presence || '.jpg'])
    tempfile.binmode
    tempfile.write(message.photo.file.read)
    tempfile.rewind

    SendTelegramMessage.call(chat_id: chat_id_for(message), text: message.body.to_s,
                             bot: :client, parse_mode: nil, photo: tempfile)
  ensure
    tempfile&.close!
  end

  def chat_id_for(message)
    message.conversation.external_chat_id
  end
end
