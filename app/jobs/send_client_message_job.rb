# frozen_string_literal: true

# Доставка ответа сотрудника клиенту. Отдельно от SendTelegramMessageJob:
# там адресат — чат по chat_id и терять нечего, кроме уведомления, а здесь у
# сообщения есть строка в БД, которую сотрудник видит в ленте, и она обязана
# честно показывать, ушло оно или нет.
#
# Отправляем фоном, потому что запрос к API мессенджера непредсказуем по
# времени: синхронная отправка держала бы форму ответа открытой всё это время.
#
# Про сам мессенджер джоба не знает ничего: канал берётся из диалога, доставку
# выполняет адаптер из ClientMessenger.
class SendClientMessageJob < ApplicationJob
  queue_as :default

  ClientMessenger.transient_errors.each do |klass|
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

    adapter = ClientMessenger.for(message.conversation)
    outcome = adapter.deliver(message)

    if outcome.success?
      message.update!(delivery_status: 'sent', sent_at: Time.current)
    elsif adapter.class.transient_error?(outcome.error)
      # Отказы самого мессенджера (клиент заблокировал бота, чат удалён)
      # постоянны — повторять их четыре раза бессмысленно.
      raise outcome.error
    else
      message.update!(delivery_status: 'failed', delivery_error: outcome.result)
    end
  end
end
