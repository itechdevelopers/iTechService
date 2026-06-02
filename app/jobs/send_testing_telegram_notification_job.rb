# frozen_string_literal: true

# Уведомляет группу технарей в Telegram об отправке устройства на тестирование.
# Чат адресуется через ENV (стандарт проекта для фиксированных бот-чатов, см. docs):
#   TELEGRAM_TECH_NOTIFICATIONS_CHAT_ID — id группы «Уведомление технарей».
# Если переменная не задана (dev / не настроенный прод) — job молча no-op'ит
# (SendTelegramMessage тоже отдельно проверяет TELEGRAM_BOT_TOKEN).
class SendTestingTelegramNotificationJob < ApplicationJob
  queue_as :default

  def perform(testing_session_id)
    # ENV читаем здесь, а не на уровне класса: значение может появиться/смениться
    # после загрузки класса (консоль, тесты, reload).
    chat_id = ENV['TELEGRAM_TECH_NOTIFICATIONS_CHAT_ID']
    return if chat_id.blank?

    session = TestingSession.find(testing_session_id)
    text = build_message(session)

    Rails.logger.info("[TestingTelegram] Sending notification for session ##{testing_session_id} to chat #{chat_id}")
    result = SendTelegramMessage.call(chat_id: chat_id, text: text)
    Rails.logger.info("[TestingTelegram] Result: #{result.result.inspect}")
  end

  private

  def build_message(session)
    service_job = session.service_job
    url = Rails.application.routes.url_helpers.service_job_url(service_job)

    <<~MSG.strip
      <b>Отправлено на тестирование</b>

      <b>Талон:</b> ##{esc(service_job.ticket_number)}
      <b>Устройство:</b> #{esc(service_job.type_name)}
      <b>Клиент:</b> #{esc(service_job.client_presentation)}

      <b>Куда:</b> #{esc(session.target_location&.name)}
      <b>Что тестировать:</b> #{esc(session.what_to_test)}
      <b>Отправил:</b> #{esc(session.sender&.short_name)}

      <a href="#{url}">Открыть ремонт</a>
    MSG
  end

  def esc(text)
    CGI.escapeHTML(text.to_s)
  end
end
