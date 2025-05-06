#frozen_string_literal: true

module Orders
  class OneCDataService
    attr_reader :order

    def initialize(order)
      @order = order
    end

    def prepare_data
      {
        order: {
          department_id: order.department_id.to_s,
          department_name: order.department&.name,
          article: order.article,
          source_store_id: order.source_store_id.to_s,
          source_store_name: order.source_store&.name,
          is_available_in_stock: order.source_store.present?,
          quantity: order.quantity,
          comment: order.comment,
          desired_date: order.desired_date&.strftime('%Y-%m-%d'),
          app_order_url: "https://ise.itech.pw/orders/#{order.id}",
          order_number: order.number
        }
      }
    end
  end
end
