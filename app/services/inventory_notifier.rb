# frozen_string_literal: true

# Уведомления по ревизии — в АйС (колокольчик + ActionCable) и в Telegram.
#
#   InventoryNotifier.notify_sent(inventory)
#
# Получатели считаются один раз и дедуплицируются: технарь филиала, которого
# товаровед вдобавок отметил в пикере, не должен получить два одинаковых
# сообщения.
class InventoryNotifier
  def self.notify_sent(inventory)
    new(inventory).notify_sent
  end

  def self.notify_submitted(inventory)
    new(inventory).notify_submitted
  end

  def self.notify_recount(inventory, count)
    new(inventory).notify_recount(count)
  end

  def initialize(inventory)
    @inventory = inventory
  end

  def notify_sent
    deliver(
      message: "Появилось задание на проведение ревизии №#{inventory.number} " \
               "(#{inventory.store&.name})",
      telegram_text: "<b>Появилось задание на проведение ревизии</b>\n" \
                     "№#{inventory.number} — #{CGI.escapeHTML(inventory.store&.name.to_s)}",
      recipients: recipients
    )
  end

  # Ревизия посчитана: уведомляем сторону товароведа. Число расхождений сразу в
  # тексте — по нему видно, надо ли бежать разбираться или можно принять как есть.
  def notify_submitted
    count = inventory.discrepancy_lines.count
    subject = "Ревизия №#{inventory.number} проведена (#{inventory.store&.name}), " \
              "расхождений: #{count}"

    deliver(
      message: subject,
      telegram_text: "<b>Ревизия проведена</b>\n#{CGI.escapeHTML(subject)}",
      recipients: review_recipients
    )
  end

  # Часть позиций вернули на пересчёт — зовём обратно тех же, кто считал.
  def notify_recount(count)
    subject = "Ревизия №#{inventory.number}: пересчитать позиций — #{count} " \
              "(#{inventory.store&.name})"

    deliver(
      message: subject,
      telegram_text: "<b>Ревизия: нужен пересчёт</b>\n#{CGI.escapeHTML(subject)}",
      recipients: recipients
    )
  end

  # Технари филиала — те, кто физически считает: сотрудники департамента склада
  # с локацией «Ремонт». Плюс отмеченные товароведом в пикере: заказчик просил
  # уметь адресовать ревизию и конкретным людям.
  def recipients
    (branch_technicians + inventory.subscribers.to_a).uniq
  end

  # Кому разбирать результат: автор ревизии, подписчики и администраторы.
  # Автор может быть в отпуске, поэтому админы здесь не «на всякий случай», а
  # чтобы ревизия не зависла без разбора.
  def review_recipients
    ([inventory.user] + inventory.subscribers.to_a + User.active.where(role: %w[admin superadmin]).to_a)
      .compact.uniq
  end

  private

  attr_reader :inventory

  def branch_technicians
    User.active
        .where(department_id: inventory.department_id)
        .where(location_id: Location.repair.ids)
        .to_a
  end

  # Возвращает число уведомлённых — контроллеру есть что показать в flash.
  def deliver(message:, telegram_text:, recipients:)
    recipients.each do |user|
      notification = Notification.create!(
        user: user,
        referenceable: inventory,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(user, notification)
      NotifyEmployeeJob.perform_later(user.id, telegram_text)
    end.size
  end

  def url
    Rails.application.routes.url_helpers.inventory_path(inventory)
  end
end
