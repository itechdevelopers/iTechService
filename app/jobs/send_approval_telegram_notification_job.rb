# frozen_string_literal: true

# Дублирует в Telegram-группу события согласования с клиентом. Один job на два
# события — текст выбирается по текущему статусу запроса:
#   pending             → технарь отправил запрос медиа (триггер из
#                         ServiceJobsController#update_repair_status)
#   approved / rejected → медиа ответила (триггер из
#                         ApprovalRequestsController#answer)
#
# Первой строкой идут @-упоминания тех, у кого на сегодня стоит рабочая смена
# (медиа или технари, см. ApprovalRecipientsQuery). Тегать некого / нет ников —
# префикс опускаем, сообщение всё равно уходит.
#
# Чат берётся из настроек Telegram-бота — записи TelegramChat, чьё название
# содержит «технарские уведомления» (регистр и обрамляющие символы не важны).
# Записи нет — job no-op'ит с предупреждением в лог: без неё остальная фича
# работает, теряются только дубли в группу (in-app-канал не зависит от неё).
class SendApprovalTelegramNotificationJob < ApplicationJob
  queue_as :default

  def perform(approval_request_id)
    # Чат ищем в момент выполнения, а не на загрузке класса: тимлид может
    # завести или переименовать группу без рестарта приложения.
    chat = TelegramChat.tech_notifications
    if chat.nil?
      Rails.logger.warn("[ApprovalTelegram] chat «#{TelegramChat::TECH_NOTIFICATIONS}» not configured, skipping request ##{approval_request_id}")
      return
    end
    chat_id = chat.chat_id

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

  # type_name/client_presentation отдают '-' вместо пустоты — строку-заглушку
  # в сообщение не тащим, иначе в чате висит «Устройство: -».
  def identity(service_job)
    lines = ["<b>Талон:</b> ##{esc(service_job.ticket_number)}"]
    lines << "<b>Устройство:</b> #{esc(service_job.type_name)}" if meaningful?(service_job.type_name)
    lines << "<b>Клиент:</b> #{esc(service_job.client_presentation)}" if meaningful?(service_job.client_presentation)
    lines.join("\n")
  end

  def meaningful?(value)
    value.present? && value != '-'
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
