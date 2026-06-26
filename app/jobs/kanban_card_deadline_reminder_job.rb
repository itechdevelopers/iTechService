# frozen_string_literal: true

# Ежедневное напоминание суперадминам о дедлайнах («Сделать до») канбан-карточек.
# Запускается cron'ом в 10:00 по Владивостоку (config/schedule.yml) и шлёт in-app
# уведомление двумя этапами:
#   * за день до дедлайна — «Завтра дедлайн…»;
#   * в сам день дедлайна — «Сегодня дедлайн…».
# Архивные карточки выпадают сами через default_scope в Kanban::Card.
# Образец daily-джобы — ClientRequestPurchaseReminderJob.
class KanbanCardDeadlineReminderJob < ApplicationJob
  queue_as :default

  def perform
    recipients = User.superadmins.active.to_a
    return if recipients.empty?

    notify_cards(Kanban::Card.where(deadline: Date.current.tomorrow), :tomorrow, recipients)
    notify_cards(Kanban::Card.where(deadline: Date.current), :today, recipients)
  end

  private

  def notify_cards(cards, phase, recipients)
    cards.find_each do |card|
      message = build_message(card, phase)
      recipients.each { |user| create_notification(user, card, message) }
    end
  end

  def create_notification(user, card, message)
    return if already_notified_today?(user, card)

    notification = Notification.create!(
      user: user,
      message: message,
      url: card.url,
      referenceable: card
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)
  end

  # Идемпотентность: если cron перезапустится в тот же день, повторное
  # уведомление по той же карточке тому же юзеру не создаётся.
  def already_notified_today?(user, card)
    Notification
      .where(user: user, referenceable: card)
      .where('created_at >= ?', Time.current.beginning_of_day)
      .exists?
  end

  def build_message(card, phase)
    prefix = phase == :today ? 'Сегодня дедлайн' : 'Завтра дедлайн'
    "#{prefix} по канбан-карточке «#{card.name}» (#{card.board_name}): " \
      "#{card.deadline.strftime('%d.%m.%Y')}."
  end
end
