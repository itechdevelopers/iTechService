# frozen_string_literal: true

# Дублирует в Telegram-группу события согласования с клиентом. Один job на два
# события — текст выбирается по текущему статусу запроса:
#   pending             → технарь отправил запрос медиа (триггер из
#                         ServiceJobsController#update_repair_status)
#   approved / rejected → медиа ответила (триггер из
#                         ApprovalRequestsController#answer)
#
# Первой строкой идут @-упоминания тех, кто должен среагировать (работающие
# сейчас по расписанию — медиа или технари, см. ApprovalRecipientsQuery).
# Тегать некого / нет ников — префикс опускаем, сообщение всё равно уходит.
#
# Чат адресуется через ENV (стандарт проекта для фиксированных бот-чатов):
#   TELEGRAM_APPROVALS_CHAT_ID — id группы согласований.
# Переменная не задана (dev / не настроенный прод) — job молча no-op'ит.
class SendApprovalTelegramNotificationJob < ApplicationJob
  queue_as :default

  def perform(approval_request_id)
    # ENV читаем здесь, а не на уровне класса: значение может появиться или
    # смениться после загрузки класса (консоль, тесты, reload).
    chat_id = ENV['TELEGRAM_APPROVALS_CHAT_ID']
    return if chat_id.blank?

    request = ApprovalRequest.find(approval_request_id)
    text = build_message(request)

    Rails.logger.info("[ApprovalTelegram] Queueing notification for request ##{approval_request_id} for chat #{chat_id}")
    # Доставку ведёт SendTelegramMessageJob (ретраи + свой лог исхода): прямой
    # вызов SendTelegramMessage молча терял бы сообщение при обрыве связи.
    SendTelegramMessageJob.perform_later(chat_id, text)
  end

  private

  def build_message(request)
    body = request.pending? ? requested_message(request) : answered_message(request)
    [mentions_line(request), body].compact.join("\n\n")
  end

  # Строка @-упоминаний. nil, если получателей или ников нет.
  def mentions_line(request)
    mentions = ApprovalRecipientsQuery.new(approval_request: request).call
                 .map { |user| user.telegram_username.presence }
                 .compact
                 .map { |nick| "@#{esc(nick)}" }
    return nil if mentions.empty?

    mentions.join(' ')
  end

  def requested_message(request)
    [
      '<b>❓ Новый запрос на согласование</b>',
      '',
      identity(request.service_job),
      '',
      "<b>Что согласовать:</b> #{esc(request.question)}",
      "<b>Запросил:</b> #{esc(request.requester&.short_name)}",
      '',
      link(request.service_job)
    ].join("\n")
  end

  def answered_message(request)
    header = request.approved? ? '✅ Согласовано' : '❌ Не согласовано'
    lines = ["<b>#{header}</b>", '', identity(request.service_job), '']
    lines << "<b>Что согласовывали:</b> #{esc(request.question)}"
    lines << "<b>Ответил:</b> #{esc(request.responder&.short_name)}"
    lines << "<b>Комментарий:</b> #{esc(request.response_comment)}" if request.response_comment.present?
    duration = duration_text(request)
    lines << "<b>Согласование заняло:</b> #{esc(duration)}" if duration
    lines << ''
    lines << link(request.service_job)
    lines.join("\n")
  end

  def identity(service_job)
    [
      "<b>Талон:</b> ##{esc(service_job.ticket_number)}",
      "<b>Устройство:</b> #{esc(service_job.type_name)}",
      "<b>Клиент:</b> #{esc(service_job.client_presentation)}"
    ].join("\n")
  end

  def duration_text(request)
    return nil unless request.responded_at

    ActionController::Base.helpers.distance_of_time_in_words(request.created_at, request.responded_at)
  end

  def link(service_job)
    url = Rails.application.routes.url_helpers.service_job_url(service_job)
    %(<a href="#{url}">Открыть ремонт</a>)
  end

  def esc(text)
    CGI.escapeHTML(text.to_s)
  end
end
