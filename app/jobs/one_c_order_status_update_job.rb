class OneCOrderStatusUpdateJob < ApplicationJob
  queue_as :default

  def perform(order_id, user_id = nil)
    order = Order.find(order_id)
    user = User.find(user_id) if user_id
    sync_record = order.one_c_sync
    
    # Skip if order is not synced
    unless sync_record&.synced? && sync_record.external_id.present?
      Rails.logger.warn "[OneCStatusUpdate] Order #{order.id} is not synced, skipping status update"
      return
    end
    
    Rails.logger.info "[OneCStatusUpdate] Updating status for order #{order.id} to #{order.status}"
    
    begin
      # Prepare status data using existing service
      data_service = Orders::OneCDataService.new(order)
      status_data = data_service.prepare_status_data
      
      # Send status update to 1C
      client = OrderClient.new
      result = client.update_order_status(order.number, status_data)
      
      if result[:success] && result[:data]['status'] == 'found'
        Rails.logger.info "[OneCStatusUpdate] Order #{order.id} status updated successfully in 1C"
        # Update external_id if provided in response
        if result[:data]['external_number'].present?
          sync_record.update!(external_id: result[:data]['external_number'])
        end
      elsif result[:success] && result[:data]['status'] == 'not_found'
        Rails.logger.error "[OneCStatusUpdate] Order #{order.id} not found in 1C"
        # Order doesn't exist in 1C, might need to create it first
      else
        Rails.logger.error "[OneCStatusUpdate] Failed to update status for order #{order.id}: #{result[:error]}"
      end
      
    rescue => e
      Rails.logger.error "[OneCStatusUpdate] Unexpected error for order #{order.id}: #{e.message}"
      raise e
    end
  end
end