class OneCOrderSyncJob < ApplicationJob
  queue_as :default

  # Define custom error classes for categorization
  class PermanentSyncError < StandardError; end
  class TransientSyncError < StandardError; end

  # Use ActiveJob's retry mechanism for transient errors only
  retry_on TransientSyncError, wait: :exponentially_longer, attempts: 5
  
  # Don't retry permanent errors - fail immediately
  discard_on PermanentSyncError

  def perform(order_id, manual_trigger: false, user_id: nil)
    if manual_trigger
      perform_manual_sync(order_id, user_id)
    else
      perform_automatic_sync(order_id)
    end
  end

  private

  def perform_automatic_sync(order_id)
    order = Order.find(order_id)
    sync_record = order.one_c_sync
    
    # Skip if already synced or no sync record exists
    return if sync_record.nil? || sync_record.synced?
    
    Rails.logger.info "[OneCSync] Starting automatic sync attempt #{sync_record.sync_attempts + 1} for order #{order.id}"
    
    perform_sync_operation(order, sync_record, automatic: true)
  end

  def perform_manual_sync(order_id, user_id)
    order = Order.find(order_id)
    user = User.find(user_id) if user_id
    sync_record = order.one_c_sync || order.ensure_one_c_sync_record!
    
    Rails.logger.info "[OneCSync] Starting manual sync for order #{order.id} requested by user #{user_id}"
    
    # Rate limiting check - prevent manual sync if last attempt was within 5 minutes
    if sync_record.last_attempt_at&.> 5.minutes.ago
      error_message = 'Попробуйте позже (ограничение: раз в 5 минут)'
      notify_user_sync_result(user, order, success: false, message: error_message) if user
      return
    end
    
    perform_sync_operation(order, sync_record, automatic: false, user: user)
  end

  def perform_sync_operation(order, sync_record, automatic:, user: nil)
    # Update sync attempt tracking
    sync_record.update!(
      sync_attempts: sync_record.sync_attempts + 1,
      last_attempt_at: Time.current,
      sync_status: :syncing
    )
    
    begin
      # Perform the actual sync
      result = perform_sync(order)
      
      if result[:success] && result[:data]['Executed'] == true
        # Success case
        Rails.logger.info "[OneCSync] Order #{order.id} synced successfully"
        
        # TODO: Commented out external_number functionality as 1C no longer provides it
        # order.update!(number: result[:data]['external_number']) if result[:data]['external_number'].present?
        sync_record.mark_sync_success!
        
        # Notify user for manual sync
        if !automatic && user
          notify_user_sync_result(user, order, success: true, message: 'Заказ успешно синхронизирован с 1С')
        end
      else
        # Failure case - categorize the error
        error_message = if result[:success] && result[:data]['Executed'] == false
                          result[:data]['Error'] || 'Unknown sync error from 1C'
                        else
                          result[:error] || 'Unknown sync error'
                        end
        categorize_and_handle_error(error_message, sync_record, automatic: automatic, user: user)
      end
      
    rescue => e
      Rails.logger.error "[OneCSync] Unexpected error during sync for order #{order.id}: #{e.message}"
      categorize_and_handle_error(e.message, sync_record, automatic: automatic, user: user)
      raise e unless !automatic # Don't re-raise for manual sync to prevent Sidekiq retry
    end
  end

  def notify_user_sync_result(user, order, success:, message:)
    return unless user
    
    Notification.create!(
      user: user,
      referenceable: order,
      message: message,
      url: Rails.application.routes.url_helpers.order_path(order)
    )
  end

  def perform_sync(order)
    data_service = Orders::OneCDataService.new(order)
    order_data = data_service.prepare_data
    
    client = OrderClient.new
    client.create_order(order_data)
  end

  def categorize_and_handle_error(error_message, sync_record, automatic: true, user: nil)
    Rails.logger.warn "[OneCSync] Sync failed for order #{sync_record.order.id}: #{error_message}"
    
    if permanent_error?(error_message)
      Rails.logger.error "[OneCSync] Permanent error detected for order #{sync_record.order.id}, will not retry"
      
      # Mark as permanently failed and notify admins
      sync_record.mark_sync_failure!(error_message)
      OneCFailureNotificationJob.perform_later(sync_record.order.id)
      
      # Notify user for manual sync
      if !automatic && user
        notify_user_sync_result(user, sync_record.order, success: false, message: "Ошибка синхронизации: #{error_message}")
      end
      
      raise PermanentSyncError, error_message if automatic
    else
      Rails.logger.info "[OneCSync] Transient error detected for order #{sync_record.order.id}, will retry"
      
      # Check if this is the final attempt (ActiveJob will not retry after 5 attempts)
      if sync_record.sync_attempts >= 5
        Rails.logger.error "[OneCSync] Final retry attempt failed for order #{sync_record.order.id}"
        sync_record.mark_sync_failure!(error_message)
        OneCFailureNotificationJob.perform_later(sync_record.order.id)
        
        # Notify user for manual sync
        if !automatic && user
          notify_user_sync_result(user, sync_record.order, success: false, message: "Синхронизация не удалась после нескольких попыток: #{error_message}")
        end
      else
        # Mark as failed but allow ActiveJob to retry (only for automatic sync)
        sync_record.update!(
          sync_status: :failed,
          last_error: error_message
        )
        
        # Notify user for manual sync (immediate failure notification)
        if !automatic && user
          notify_user_sync_result(user, sync_record.order, success: false, message: "Ошибка синхронизации: #{error_message}")
        end
      end
      
      raise TransientSyncError, error_message if automatic
    end
  end

  def permanent_error?(error_message)
    # Categorize errors based on HTTP status codes and error patterns
    return true if error_message.match?(/Код ответа: 4\d{2}/)  # 4xx errors are permanent
    return true if error_message.include?('authentication')
    return true if error_message.include?('validation')
    return true if error_message.include?('invalid')
    
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