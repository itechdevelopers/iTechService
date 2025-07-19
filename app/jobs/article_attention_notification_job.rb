class ArticleAttentionNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    
    # Get all active admins in the same department as the order
    admins = User.any_admin.active.where(department: order.department)
    
    admins.each do |admin|
      Notification.create!(
        user: admin,
        referenceable: order,
        message: "Создан заказ без артикула, <a href=\"/orders/#{order.id}/edit\">обратите внимание</a>",
        url: Rails.application.routes.url_helpers.edit_order_path(order)
      )
    end
  end
end