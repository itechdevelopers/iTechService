class ArticleAttentionNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    
    # Get all active users with merchandiser notification ability in the same department as the order
    recipients = User.active.with_ability('receive_merchandiser_notifications').in_department(order.department_id)
    
    recipients.each do |recipient|
      Notification.create!(
        user: recipient,
        referenceable: order,
        message: "Создан заказ без артикула, <a href=\"/orders/#{order.id}/edit\">обратите внимание</a>",
        url: Rails.application.routes.url_helpers.edit_order_path(order)
      )
    end
  end
end