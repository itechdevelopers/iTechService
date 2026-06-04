# frozen_string_literal: true

# Создаёт персональные in-app Notification-записи о событии тестирования и
# броадкастит их через ActionCable. Параллельный канал к
# SendTestingTelegramNotificationJob: тот шлёт ОДНО сообщение в общий чат с
# @-тегами, этот — по записи на каждого получателя (модалка/поповер в АИС).
#
# Образец — RepairAttentionNotifier#notify_user, но на коллекцию получателей.
# Получателей подбирает TestingRecipientsQuery с fallback_to_attached: true:
# если по расписанию сейчас никого нет — шлём всем прикреплённым к локации
# (in-app обязано до кого-то дойти; ника, в отличие от Telegram, не требует).
#
# Текст и url зависят от направления устройства (going_to_test?):
#   на тест (not_started / failed+retry)         → /testings
#   обратно к технарям (passed / failed+return)  → /testings/returned
class TestingInAppNotifier
  def self.call(session)
    new(session).call
  end

  def initialize(session)
    @session = session
  end

  def call
    recipients.each do |user|
      notification = Notification.create!(
        user: user,
        referenceable: session,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end

  private

  attr_reader :session

  def recipients
    TestingRecipientsQuery.new(session: session).call(fallback_to_attached: true)
  end

  # Устройство едет (или остаётся) на тест: первая отправка или повторный тест.
  # (Зеркалит одноимённый предикат в TestingRecipientsQuery — тот же критерий
  # направления, но здесь решает текст/url, а не аудиторию.)
  def going_to_test?
    session.not_started? ||
      (session.failed? && session.failure_action == TestingSession::FAILURE_ACTIONS[:retry])
  end

  def message
    key = going_to_test? ? 'testing_to_test' : 'testing_returned'
    I18n.t("notifications.#{key}", ticket: session.service_job.ticket_number)
  end

  def url
    helpers = Rails.application.routes.url_helpers
    going_to_test? ? helpers.testings_path : helpers.returned_testings_path
  end
end
