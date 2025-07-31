#frozen_string_literal: true

class OrderClient < OneCBaseClient
  def create_order(order_data)
    path = '/UT/hs/ice_int/v1/UploadOrder/'
    make_request(path, method: :post, body: order_data)
  end

  def update_order(order_number, order_data)
    path = "/UT/hs/ice_int/v1/UpdateOrder/#{order_number}"
    make_request(path, method: :put, body: order_data)
  end

  def check_order_status(order_number)
    path = "/UT/hs/ice_int/v1/OrderStatus/#{order_number}"
    make_request(path, method: :get)
  end
end

