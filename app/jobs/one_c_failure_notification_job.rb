class OneCFailureNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    sync_record = order.one_c_sync
    
    return unless sync_record&.permanently_failed?
    
    # Get all active users with merchandiser notification ability in the same department as the order
    recipients = User.active.with_ability('receive_merchandiser_notifications').in_department(order.department_id)
    
    Rails.logger.info "[OneCFailureNotification] Notifying #{recipients.count} users with merchandiser notifications about permanent sync failure for order #{order.id}"
    
    recipients.each do |recipient|
      Notification.create!(
        user: recipient,
        referenceable: order,
        message: "Ошибка синхронизации заказа с 1С, <a href=\"/orders/#{order.id}/edit\">требуется вмешательство</a>",
        url: Rails.application.routes.url_helpers.edit_order_path(order)
      )
    end
  end
end