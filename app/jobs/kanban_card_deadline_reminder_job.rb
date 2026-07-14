# frozen_string_literal: true

# Ежедневное напоминание о дедлайнах («Сделать до») канбан-карточек.
# Запускается cron'ом в 10:00 по Владивостоку (config/schedule.yml) и шлёт in-app
# уведомления тремя этапами:
#   * за день до дедлайна   — «Завтра дедлайн…»;
#   * в сам день дедлайна   — «Сегодня дедлайн…»;
#   * каждый день просрочки — «Просрочен дедлайн…» (пока карточка не закрыта).
# Получатели: суперадмины (видят все дедлайны) + ответственные карточки (card.managers).
# Ответственным, привязавшим личный Telegram (user.telegram_linked?), тот же текст
# дублируется личным сообщением бота. Суперадминам TG не шлём — только in-app.
# Карточки в колонках с флагом «Готово» (column.done) полностью исключаются.
# Архивные карточки выпадают сами через default_scope в Kanban::Card.
# Образец daily-джобы — ClientRequestPurchaseReminderJob.
class KanbanCardDeadlineReminderJob < ApplicationJob
  queue_as :default

  def perform
    @superadmins = User.superadmins.active.to_a

    notify_cards(cards_with_deadline(Date.current.tomorrow), :tomorrow)
    notify_cards(cards_with_deadline(Date.current), :today)
    notify_cards(overdue_cards, :overdue)
  end

  private

  def cards_with_deadline(date)
    Kanban::Card.where(deadline: date)
  end

  # Каждый день после наступления срока, пока карточку не закрыли (колонка «Готово»)
  # или не заархивировали. Границу берём строго «<», т.к. сам день дедлайна — фаза :today.
  def overdue_cards
    Kanban::Card.where('deadline < ?', Date.current)
  end

  def notify_cards(cards, phase)
    cards.includes(:column, :managers).find_each do |card|
      next if card.column.done?

      message  = build_message(card, phase)
      managers = card.managers.active.to_a

      (@superadmins + managers).uniq.each do |user|
        created = create_notification(user, card, message)
        # Личный TG-дубль — только ответственным и только при новом уведомлении,
        # чтобы повторный запуск cron в тот же день не задублировал сообщение.
        notify_telegram(user, message) if created && managers.include?(user) && user.telegram_linked?
      end
    end
  end

  # Возвращает true, если уведомление создано; false — если уже уведомляли сегодня.
  def create_notification(user, card, message)
    return false if already_notified_today?(user, card)

    notification = Notification.create!(
      user: user,
      message: message,
      url: card.url,
      referenceable: card
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)
    true
  end

  def notify_telegram(user, message)
    SendTelegramMessage.call(chat_id: user.telegram_chat_id, text: message)
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
    prefix = case phase
             when :today   then 'Сегодня дедлайн'
             when :overdue then 'Просрочен дедлайн'
             else               'Завтра дедлайн'
             end
    "#{prefix} по канбан-карточке «#{card.name}» (#{card.board_name}): " \
      "#{card.deadline.strftime('%d.%m.%Y')}."
  end
end
