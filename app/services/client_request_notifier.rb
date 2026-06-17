# frozen_string_literal: true

# Создаёт персональные in-app Notification-записи о результате проверки покупки
# (фича «Запросы клиента») и броадкастит их через ActionCable.
# Образец — TestingInAppNotifier, но получатели и текст специфичны для запроса.
#
# Цвет/жирность задаются через Notification#kind (НЕ через HTML в message —
# message остаётся plain text, см. план §2.2). CSS навешивается по классу
# single-notification--client-request-<bucket> (см. notifications_popover.css.scss).
class ClientRequestNotifier
  def self.notify_confirmed(request)
    new(request).notify_confirmed
  end

  def self.notify_unconfirmed(request)
    new(request).notify_unconfirmed
  end

  def initialize(request)
    @request = request
  end

  # Покупка подтверждена: kind по «корзине» срока (under_year/one_to_two/over_two),
  # message — кто/когда куплено и сколько прошло.
  def notify_confirmed
    deliver(
      kind: "client_request_#{@request.usage_bucket}",
      message: "Запрос чека: #{client_name}, куплен #{purchase_date}, " \
               "прошло #{@request.usage_days} дн."
    )
  end

  # Покупку подтвердить не удалось (1С недоступна / устройство не продано).
  def notify_unconfirmed
    deliver(
      kind: 'client_request_unconfirmed',
      message: "Запрос чека: #{client_name} — не удалось подтвердить покупку"
    )
  end

  private

  attr_reader :request

  def deliver(kind:, message:)
    ClientRequest.notification_recipients.each do |user|
      notification = Notification.create!(
        user: user,
        referenceable: request,
        kind: kind,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(user, notification)
    end
  end

  def client_name
    request.client.short_name
  end

  def purchase_date
    I18n.l(request.sold_at)
  end

  def url
    Rails.application.routes.url_helpers.client_request_path(request)
  end
end
