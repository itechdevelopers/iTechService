class ArticleAttentionNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    
    # Get all active users with merchandiser notification ability in the same department as the order
    recipients = User.active.with_ability('receive_merchandiser_notifications').in_department(order.department_id)
    
    recipients.each do |recipient|
      NotificationDispatcher.call(
        user: recipient,
        type_key: 'order_without_article',
        message: "Создан заказ без артикула, <a href=\"/orders/#{order.id}/edit\">обратите внимание</a>",
        url: Rails.application.routes.url_helpers.edit_order_path(order),
        referenceable: order,
        telegram_text: 'Создан заказ без артикула — требуется проверка'
      )
    end
  end
end