#frozen_string_literal: true

class OrderClient < OneCBaseClient
  def create_order(order_data)
    path = '/UT/hs/ice_int/v1/UploadOrder/'
    make_request(path, method: :post, body: order_data)
  end

  def update_order(external_id, order_data)
    path = "/UT/hs/ice_int/v1/UpdateOrder/#{external_id}"
    make_request(path, method: :put, body: order_data)
  end

  def check_order_status(external_id)
    path = "/UT/hs/ice_int/v1/OrderStatus/#{external_id}"
    make_request(path, method: :get)
  end
end

