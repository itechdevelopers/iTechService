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

  def initialize(inventory)
    @inventory = inventory
  end

  def notify_sent
    deliver(
      message: "Появилось задание на проведение ревизии №#{inventory.number} " \
               "(#{inventory.store&.name})",
      telegram_text: "<b>Появилось задание на проведение ревизии</b>\n" \
                     "№#{inventory.number} — #{CGI.escapeHTML(inventory.store&.name.to_s)}"
    )
  end

  # Технари филиала — те, кто физически считает: сотрудники департамента склада
  # с локацией «Ремонт». Плюс отмеченные товароведом в пикере: заказчик просил
  # уметь адресовать ревизию и конкретным людям.
  def recipients
    (branch_technicians + inventory.subscribers.to_a).uniq
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
  def deliver(message:, telegram_text:)
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
