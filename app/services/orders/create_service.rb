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

        # Enqueue background sync job immediately (no immediate sync attempt)
        OneCOrderSyncJob.perform_later(order.id)
        Rails.logger.info "[OrderService] Order #{order.id} created, sync job enqueued"

        OrdersMailer.notice(order.id).deliver_later
        message = I18n.t('orders.created_pending_sync')

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

  end
end
