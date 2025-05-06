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
        one_c_response = send_to_one_c(order)

        if one_c_response[:success] && one_c_response[:data]['external_number'].present?
          order.number = one_c_response[:data]['external_number']
          order.one_c_synced = true
        end

        return { order: order, success: false, message: order.errors.full_messages.join(', ') } unless order.save

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
      if one_c_response[:success]
        I18n.t('orders.created_with_one_c', number: one_c_response[:data]['external_number'])
      else
        error_message = one_c_response[:error] || I18n.t('orders.one_c_error_default')
        I18n.t('orders.created_without_one_c', error: error_message)
      end
    end
  end
end
