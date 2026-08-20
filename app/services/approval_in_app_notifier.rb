# frozen_string_literal: true

# Создаёт персональные in-app Notification-записи о событии согласования и
# броадкастит их через ActionCable. Параллельный канал к
# SendApprovalTelegramNotificationJob: тот шлёт ОДНО сообщение в группу с
# @-тегами, этот — по записи на каждого получателя. Каналы независимы: in-app
# доходит и тогда, когда Telegram недоступен или группа не заведена.
#
# Получателей подбирает ApprovalRecipientsQuery с fallback_to_attached: true —
# если на сегодня расписания нет вовсе, шлём всем прикреплённым к локации:
# in-app обязано до кого-то дойти, ника (в отличие от Telegram) не требует.
#
# Направление определяет и адресата, и текст со ссылкой:
#   pending  → медиа, ссылка на дашборд с блоком «Согласование»;
#   answered → технари, ссылка на витрину «С согласования».
class ApprovalInAppNotifier
  def self.call(approval_request)
    new(approval_request).call
  end

  def initialize(approval_request)
    @approval_request = approval_request
  end

  def call
    recipients.each do |user|
      notification = Notification.create!(
        user: user,
        referenceable: approval_request,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end

  private

  attr_reader :approval_request

  def recipients
    ApprovalRecipientsQuery.new(approval_request: approval_request).call(fallback_to_attached: true)
  end

  def message
    ticket = approval_request.service_job.ticket_number

    if approval_request.pending?
      I18n.t('notifications.approval_requested', ticket: ticket)
    else
      I18n.t("notifications.approval_#{approval_request.status}", ticket: ticket)
    end
  end

  def url
    helpers = Rails.application.routes.url_helpers
    approval_request.pending? ? helpers.root_path : helpers.answered_approval_requests_path
  end
end
