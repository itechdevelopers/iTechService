# frozen_string_literal: true

# Повторное напоминание об уже отправленном уведомлении: сотрудник сам задаёт в
# профиле, сколько раз и с каким шагом его дёргать.
#
# Каналы напоминают по-разному. В колокольчике запись висит, пока её не
# закроют, — второй такой же строки не нужно, и повтор там сводится к
# переброадкасту существующей: иконка снова привлекает внимание. В Telegram
# запись «переподнять» нечем, поэтому уходит новое сообщение.
#
# Текст для Telegram передаётся аргументом: он собран в момент доставки, и
# пересобирать его на каждом повторе значило бы тянуть за собой всю ситуацию,
# которой к тому времени может не быть (работа уехала, статус сменился).
class NotificationRepeatJob < ApplicationJob
  queue_as :default

  def perform(notification_id, telegram_text = nil, attempt = 1)
    notification = Notification.find_by(id: notification_id)
    return if notification.nil? || notification.closed?

    user = notification.user
    return if user.nil?

    preference = UserNotificationPreference.for(user, notification.type_key)
    return if preference.nil? || !preference.repeats?
    return if attempt > preference.repeat_count
    return if outside_window?(notification, preference)

    notification.update_columns(repeats_sent: attempt)

    remind_in_app(notification, preference)
    remind_telegram(user, preference, telegram_text)

    schedule_next(notification, preference, telegram_text, attempt)
  end

  private

  # Окно отсчитывается от самого уведомления: напоминание про фото при приёмке
  # бессмысленно после того, как минус уже выставлен.
  def outside_window?(notification, preference)
    window = preference.entry&.repeat_window_minutes
    return false if window.nil?

    notification.created_at < window.minutes.ago
  end

  def remind_in_app(notification, preference)
    return unless preference.deliver?(:in_app)
    return if notification.hidden?

    UserNotificationChannel.broadcast_to(notification.user, notification)
  end

  def remind_telegram(user, preference, telegram_text)
    return if telegram_text.blank?
    return unless preference.deliver?(:telegram)
    return unless user.telegram_linked?

    NotifyEmployeeJob.perform_later(user.id, telegram_text)
  end

  def schedule_next(notification, preference, telegram_text, attempt)
    return if attempt >= preference.repeat_count

    self.class.set(wait: preference.repeat_interval_minutes.minutes)
        .perform_later(notification.id, telegram_text, attempt + 1)
  end
end
