class OneCOrderSyncJob < ApplicationJob
  queue_as :default

  # Define custom error classes for categorization
  class PermanentSyncError < StandardError; end
  class TransientSyncError < StandardError; end

  # Use ActiveJob's retry mechanism for transient errors only
  retry_on TransientSyncError, wait: :exponentially_longer, attempts: 5
  
  # Don't retry permanent errors - fail immediately
  discard_on PermanentSyncError

  def perform(order_id)
    order = Order.find(order_id)
    sync_record = order.one_c_sync
    
    # Skip if already synced or no sync record exists
    return if sync_record.nil? || sync_record.synced?
    
    Rails.logger.info "[OneCSync] Starting sync attempt #{sync_record.sync_attempts + 1} for order #{order.id}"
    
    # Update sync attempt tracking
    sync_record.update!(
      sync_attempts: sync_record.sync_attempts + 1,
      last_attempt_at: Time.current,
      sync_status: :syncing
    )
    
    begin
      # Perform the actual sync
      result = perform_sync(order)
      
      if result[:success] && result[:data]['external_number'].present?
        # Success case
        Rails.logger.info "[OneCSync] Order #{order.id} synced successfully with external_id: #{result[:data]['external_number']}"
        
        order.update!(number: result[:data]['external_number']) if result[:data]['external_number'].present?
        sync_record.mark_sync_success!(result[:data]['external_number'])
      else
        # Failure case - categorize the error
        error_message = result[:error] || 'Unknown sync error'
        categorize_and_handle_error(error_message, sync_record)
      end
      
    rescue => e
      Rails.logger.error "[OneCSync] Unexpected error during sync for order #{order.id}: #{e.message}"
      categorize_and_handle_error(e.message, sync_record)
      raise e
    end
  end

  private

  def perform_sync(order)
    data_service = Orders::OneCDataService.new(order)
    order_data = data_service.prepare_data
    
    client = OrderClient.new
    client.create_order(order_data)
  end

  def categorize_and_handle_error(error_message, sync_record)
    Rails.logger.warn "[OneCSync] Sync failed for order #{sync_record.order.id}: #{error_message}"
    
    if permanent_error?(error_message)
      Rails.logger.error "[OneCSync] Permanent error detected for order #{sync_record.order.id}, will not retry"
      
      # Mark as permanently failed and notify admins
      sync_record.mark_sync_failure!(error_message)
      OneCFailureNotificationJob.perform_later(sync_record.order.id)
      
      raise PermanentSyncError, error_message
    else
      Rails.logger.info "[OneCSync] Transient error detected for order #{sync_record.order.id}, will retry"
      
      # Check if this is the final attempt (ActiveJob will not retry after 5 attempts)
      if sync_record.sync_attempts >= 5
        Rails.logger.error "[OneCSync] Final retry attempt failed for order #{sync_record.order.id}"
        sync_record.mark_sync_failure!(error_message)
        OneCFailureNotificationJob.perform_later(sync_record.order.id)
      else
        # Mark as failed but allow ActiveJob to retry
        sync_record.update!(
          sync_status: :failed,
          last_error: error_message
        )
      end
      
      raise TransientSyncError, error_message
    end
  end

  def permanent_error?(error_message)
    # Categorize errors based on HTTP status codes and error patterns
    return true if error_message.match?(/Код ответа: 4\d{2}/)  # 4xx errors are permanent
    return true if error_message.include?('authentication')
    return true if error_message.include?('validation')
    return true if error_message.include?('invalid')
    
    # All other errors (5xx, timeouts, network issues) are considered transient
    false
  end
end