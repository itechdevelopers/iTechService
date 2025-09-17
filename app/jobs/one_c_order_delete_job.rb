class OneCOrderDeleteJob < ApplicationJob
  queue_as :default

  # No retry mechanism for delete operations as specified
  
  def perform(order_id, user_id = nil)
    order = Order.find(order_id)
    user = User.find(user_id) if user_id
    sync_record = order.one_c_sync
    
    # Skip if order is not synced or has no external_id
    unless sync_record&.synced? && sync_record.external_id.present?
      Rails.logger.warn "[OneCDelete] Order #{order.id} is not synced, skipping deletion"
      notify_user_delete_result(user, order, success: false, message: 'Заказ не синхронизирован с 1С') if user
      return
    end
    
    Rails.logger.info "[OneCDelete] Starting deletion for order #{order.id} with identifier: #{order.number}"
    
    begin
      perform_order_deletion(order, sync_record, user)
      
    rescue => e
      Rails.logger.error "[OneCDelete] Unexpected error during deletion for order #{order.id}: #{e.message}"
      notify_user_delete_result(user, order, success: false, message: "Ошибка при удалении заказа: #{e.message}") if user
      raise e
    end
  end

  private

  def perform_order_deletion(order, sync_record, user)
    client = OrderClient.new
    result = client.delete_order(order.number)
    
    if result[:success] && result[:data]['status'] == 'success'
      Rails.logger.info "[OneCDelete] Order #{order.id} deleted successfully from 1C"
      
      # Mark as deleted in our system
      sync_record.mark_deletion_success!
      
      notify_user_delete_result(user, order, success: true, message: 'Заказ успешно удален из 1С') if user
    else
      # Handle deletion errors
      error_message = if result[:success] && result[:data]['status'] == 'error'
                        result[:data]['message'] || 'Unknown deletion error from 1C'
                      else
                        result[:error] || 'Unknown deletion error'
                      end
      
      # Check if this is "not found" error - treat as success since order is already gone
      if error_message.include?('не найден в базе')
        Rails.logger.info "[OneCDelete] Order #{order.id} not found in 1C, treating as successful deletion"
        sync_record.mark_deletion_success!
        notify_user_delete_result(user, order, success: true, message: 'Заказ не найден в 1С (уже удален)') if user
      else
        Rails.logger.error "[OneCDelete] Deletion failed for order #{order.id}: #{error_message}"
        notify_user_delete_result(user, order, success: false, message: "Ошибка удаления: #{error_message}") if user
      end
    end
  end

  def notify_user_delete_result(user, order, success:, message:)
    return unless user
    
    Notification.create!(
      user: user,
      referenceable: order,
      message: message,
      url: Rails.application.routes.url_helpers.order_path(order)
    )
  end
end