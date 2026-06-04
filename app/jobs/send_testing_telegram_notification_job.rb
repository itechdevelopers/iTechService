# frozen_string_literal: true

# Уведомляет группу технарей в Telegram о событиях тестирования устройства.
# Один job на три события — текст выбирается по текущему статусу сессии:
#   not_started → отправлено на тест (триггер из ServiceJobsController#update_repair_status)
#   passed      → тест пройден      (триггер из TestingsController#finish)
#   failed      → тест не пройден   (триггер из TestingsController#finish)
#
# Первой строкой сообщения идут @-упоминания сотрудников, которые должны
# среагировать (работающие сейчас по расписанию на нужной локации) —
# их подбирает TestingMentionRecipientsQuery по направлению устройства.
# Если тегать некого / нет ников — префикс опускается (сообщение всё равно шлётся).
#
# Чат адресуется через ENV (стандарт проекта для фиксированных бот-чатов, см. docs):
#   TELEGRAM_DEVICE_TESTING_CHAT_ID — id группы «Уведомление технарей».
# Если переменная не задана (dev / не настроенный прод) — job молча no-op'ит
# (SendTelegramMessage тоже отдельно проверяет TELEGRAM_BOT_TOKEN).
class SendTestingTelegramNotificationJob < ApplicationJob
  queue_as :default

  def perform(testing_session_id)
    # ENV читаем здесь, а не на уровне класса: значение может появиться/смениться
    # после загрузки класса (консоль, тесты, reload).
    chat_id = ENV['TELEGRAM_DEVICE_TESTING_CHAT_ID']
    return if chat_id.blank?

    session = TestingSession.find(testing_session_id)
    text = build_message(session)

    Rails.logger.info("[TestingTelegram] Sending notification for session ##{testing_session_id} to chat #{chat_id}")
    result = SendTelegramMessage.call(chat_id: chat_id, text: text)
    Rails.logger.info("[TestingTelegram] Result: #{result.result.inspect}")
  end

  private

  def build_message(session)
    body =
      case session.status
      when 'passed' then finished_message(session, header: '✅ Тест пройден успешно', failed: false)
      when 'failed' then finished_message(session, header: '❌ Тест не пройден', failed: true)
      else sent_message(session)
      end
    # @-теги сотрудников, которые должны среагировать (работающие сейчас по
    # расписанию на нужной локации), идут первой строкой. Если тегать некого
    # или ни у кого не заполнен ник — шлём сообщение без префикса (fallback).
    [mentions_line(session), body].compact.join("\n\n")
  end

  # Строка @-упоминаний из ников Telegram. nil, если получателей/ников нет.
  def mentions_line(session)
    mentions = TestingMentionRecipientsQuery.new(session: session).call
                 .map { |user| user.telegram_username.presence }
                 .compact
                 .map { |nick| "@#{esc(nick)}" }
    return nil if mentions.empty?

    mentions.join(' ')
  end

  # Уведомление об отправке устройства на тест.
  def sent_message(session)
    [
      '<b>Отправлено на тестирование</b>',
      '',
      identity(session.service_job),
      '',
      "<b>Куда:</b> #{esc(session.target_location&.name)}",
      "<b>Что тестировать:</b> #{esc(session.what_to_test)}",
      "<b>Отправил:</b> #{esc(session.sender&.short_name)}",
      '',
      link(session.service_job)
    ].join("\n")
  end

  # Уведомление о завершении теста (passed/failed).
  def finished_message(session, header:, failed:)
    lines = ["<b>#{header}</b>", '', identity(session.service_job), '']
    lines << "<b>Что тестировали:</b> #{esc(session.what_to_test)}"
    lines << "<b>Тестировал:</b> #{esc(session.tester&.short_name)}"
    lines << "<b>Действие:</b> #{esc(failure_action_label(session))}" if failed
    duration = duration_text(session)
    lines << "<b>Длительность:</b> #{esc(duration)}" if duration
    lines << "<b>Заметки:</b> #{esc(session.notes)}" if session.notes.present?
    lines << ''
    lines << link(session.service_job)
    lines.join("\n")
  end

  # Общий блок идентификации устройства/ремонта.
  def identity(service_job)
    [
      "<b>Талон:</b> ##{esc(service_job.ticket_number)}",
      "<b>Устройство:</b> #{esc(service_job.type_name)}",
      "<b>Клиент:</b> #{esc(service_job.client_presentation)}"
    ].join("\n")
  end

  def failure_action_label(session)
    case session.failure_action
    when TestingSession::FAILURE_ACTIONS[:return_to_tech] then 'Вернуть технарю'
    when TestingSession::FAILURE_ACTIONS[:retry]          then 'Повторное тестирование'
    end
  end

  def duration_text(session)
    return nil unless session.started_at && session.ended_at
    ActionController::Base.helpers.distance_of_time_in_words(session.started_at, session.ended_at)
  end

  def link(service_job)
    url = Rails.application.routes.url_helpers.service_job_url(service_job)
    %(<a href="#{url}">Открыть ремонт</a>)
  end

  def esc(text)
    CGI.escapeHTML(text.to_s)
  end
end
