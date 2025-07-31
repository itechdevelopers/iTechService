#frozen_string_literal: true

module Orders
  class CreateService
    attr_reader :params, :current_user

    def initialize(params, current_user)
      @params = params
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do 
        order = build_order
        order.generate_number

        return { order: order, success: false, message: order.errors.full_messages.join(', ') } unless order.save

        # Create sync record
        sync_record = order.external_syncs.create!(
          external_system: :one_c,
          sync_status: :pending,
          attention_required: order.article_requires_attention?
        )

        # Handle article attention immediately if needed
        if order.article_requires_attention?
          ArticleAttentionNotificationJob.perform_later(order.id)
        end

        # Attempt immediate 1C sync for fast success path
        sync_record.update!(
          sync_attempts: sync_record.sync_attempts + 1,
          last_attempt_at: Time.current,
          sync_status: :syncing
        )
        one_c_response = send_to_one_c(order)
        
        if one_c_response[:success] && one_c_response[:data]['Executed'] == true
          # Success: update sync record immediately
          # TODO: Commented out external_number functionality as 1C no longer provides it
          # order.update!(number: one_c_response[:data]['external_number'])
          sync_record.mark_sync_success!
          Rails.logger.info "[OrderService] Order #{order.id} synced successfully on creation"
        else
          # Failure: reset sync status and enqueue background retry job
          error_message = if one_c_response[:success] && one_c_response[:data]['Executed'] == false
                            one_c_response[:data]['Error'] || 'Unknown 1C sync error'
                          else
                            one_c_response[:error] || 'Unknown 1C sync error'
                          end
          Rails.logger.warn "[OrderService] Immediate sync failed for order #{order.id}: #{error_message}"
          
          sync_record.update!(
            sync_status: :pending,
            sync_attempts: 0,  # Reset attempts for background job to handle
            last_error: error_message
          )
          
          # Enqueue background retry job
          OneCOrderSyncJob.perform_later(order.id)
        end

        OrdersMailer.notice(order.id).deliver_later
        message = create_status_message(one_c_response)

        { order: order, success: true, message: message }
      end
    end

    private

    def build_order
      order = Order.new(params)

      if order.customer_id.blank?
        order.customer_id = current_user.id
        order.customer_type = 'User'
      else
        order.customer_type = 'Client'
      end

      order.user_id ||= current_user.id
      order
    end

    def send_to_one_c(order)
      data_service = Orders::OneCDataService.new(order)
      order_data = data_service.prepare_data

      client = OrderClient.new
      client.create_order(order_data)
    end

    def create_status_message(one_c_response)
      if one_c_response[:success] && one_c_response[:data]['Executed'] == true
        # TODO: Updated for new 1C response format - no longer provides external_number
        I18n.t('orders.created_with_one_c', number: 'система 1С')
      else
        error_message = if one_c_response[:success] && one_c_response[:data]['Executed'] == false
                          one_c_response[:data]['Error'] || I18n.t('orders.one_c_error_default')
                        else
                          one_c_response[:error] || I18n.t('orders.one_c_error_default')
                        end
        I18n.t('orders.created_without_one_c', error: error_message)
      end
    end
  end
end
