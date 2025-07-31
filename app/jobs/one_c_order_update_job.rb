class OneCOrderUpdateJob < ApplicationJob
  queue_as :default

  # Define custom error classes for categorization
  class PermanentUpdateError < StandardError; end
  class TransientUpdateError < StandardError; end

  # Use ActiveJob's retry mechanism for transient errors only
  retry_on TransientUpdateError, wait: :exponentially_longer, attempts: 3
  
  # Don't retry permanent errors - fail immediately
  discard_on PermanentUpdateError

  def perform(order_id, user_id = nil)
    order = Order.find(order_id)
    user = User.find(user_id) if user_id
    sync_record = order.one_c_sync
    
    # Skip if order is not synced or has no external_id
    unless sync_record&.synced? && sync_record.external_id.present?
      Rails.logger.warn "[OneCUpdate] Order #{order.id} is not synced, skipping update"
      return
    end
    
    # Note: Using order.number as identifier since 1C expects the original order number, not external_id
    Rails.logger.info "[OneCUpdate] Starting update for order #{order.id} with identifier: #{order.number}"
    
    begin
      # First, check if the order still exists in 1C
      client = OrderClient.new
      status_result = client.check_order_status(order.number)
      
      if status_result[:success] && status_result[:data]['status'] == 'found'
        # Order exists, perform update
        perform_order_update(order, sync_record, user)
      else
        # Order doesn't exist in 1C (status: 'not_found') or other error, treat as new order creation
        Rails.logger.warn "[OneCUpdate] Order #{order.id} not found in 1C, performing creation instead"
        perform_order_creation(order, sync_record, user)
      end
      
    rescue => e
      Rails.logger.error "[OneCUpdate] Unexpected error during update for order #{order.id}: #{e.message}"
      categorize_and_handle_error(e.message, order, user)
      raise e
    end
  end

  private

  def perform_order_update(order, sync_record, user)
    data_service = Orders::OneCDataService.new(order)
    order_data = data_service.prepare_data
    
    client = OrderClient.new
    result = client.update_order(order.number, order_data)
    
    if result[:success] && result[:data]['status'] == 'success'
      Rails.logger.info "[OneCUpdate] Order #{order.id} updated successfully in 1C"
      # TODO: 1C provides external_number in update responses but we keep it commented out
      # order.update!(number: result[:data]['external_number']) if result[:data]['external_number'].present?
      notify_user_update_result(user, order, success: true, message: 'Заказ успешно обновлен в 1С') if user
    else
      error_message = if result[:success] && result[:data]['status'] == 'error'
                        result[:data]['message'] || 'Unknown update error from 1C'
                      else
                        result[:error] || 'Unknown update error'
                      end
      categorize_and_handle_error(error_message, order, user)
    end
  end

  def perform_order_creation(order, sync_record, user)
    # Reset sync record to pending and let the sync job handle it
    sync_record.update!(
      sync_status: :pending,
      external_id: nil,
      sync_attempts: 0
    )
    
    # Use existing sync job to recreate the order
    OneCOrderSyncJob.perform_later(order.id, manual_trigger: user.present?, user_id: user&.id)
    
    Rails.logger.info "[OneCUpdate] Order #{order.id} queued for recreation in 1C"
  end

  def categorize_and_handle_error(error_message, order, user)
    Rails.logger.warn "[OneCUpdate] Update failed for order #{order.id}: #{error_message}"
    
    if permanent_error?(error_message)
      Rails.logger.error "[OneCUpdate] Permanent error detected for order #{order.id}, will not retry"
      
      # Notify user about permanent failure
      if user
        notify_user_update_result(user, order, success: false, message: "Ошибка обновления заказа: #{error_message}")
      end
      
      raise PermanentUpdateError, error_message
    else
      Rails.logger.info "[OneCUpdate] Transient error detected for order #{order.id}, will retry"
      
      # For transient errors, let ActiveJob handle retries
      # Only notify user on final failure (handled by retry mechanism)
      
      raise TransientUpdateError, error_message
    end
  end

  def notify_user_update_result(user, order, success:, message:)
    return unless user
    
    Notification.create!(
      user: user,
      referenceable: order,
      message: message,
      url: Rails.application.routes.url_helpers.order_path(order)
    )
  end

  def permanent_error?(error_message)
    # Same categorization logic as sync job
    return true if error_message.match?(/Код ответа: 4\d{2}/)  # 4xx errors are permanent
    return true if error_message.include?('authentication')
    return true if error_message.include?('validation')
    return true if error_message.include?('invalid')
    return true if error_message.include?('not found')  # Order not found is permanent for updates
    
    # Business logic errors from 1C (these come via 500 + JSON body, now parsed as success: true)
    return true if error_message.include?('не удалось')  # "failed to..." type messages
    return true if error_message.include?('не найден в базе')  # "not found in database"
    return true if error_message.include?('неверный формат')  # "invalid format"
    return true if error_message.include?('недостаточно данных')  # "insufficient data"
    return true if error_message.include?('дублирование')  # "duplication"
    
    # All other errors (network, timeouts) are considered transient
    false
  end
end