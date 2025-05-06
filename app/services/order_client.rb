#frozen_string_literal: true

class OrderClient < OneCBaseClient
  def create_order(order_data)
    path = '/api/orders/create'
    make_request(path, method: :post, body: order_data)
  end
end

