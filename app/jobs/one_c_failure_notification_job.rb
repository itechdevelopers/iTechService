class OneCFailureNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    sync_record = order.one_c_sync
    
    return unless sync_record&.permanently_failed?
    
    # Get all active admins in the same department as the order
    admins = User.any_admin.active.where(department: order.department)
    
    Rails.logger.info "[OneCFailureNotification] Notifying #{admins.count} admins about permanent sync failure for order #{order.id}"
    
    admins.each do |admin|
      Notification.create!(
        user: admin,
        referenceable: order,
        message: "Ошибка синхронизации заказа с 1С, <a href=\"/orders/#{order.id}/edit\">требуется вмешательство</a>",
        url: Rails.application.routes.url_helpers.edit_order_path(order)
      )
    end
  end
end