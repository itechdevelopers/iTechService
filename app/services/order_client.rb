#frozen_string_literal: true

class OrderClient < OneCBaseClient
  def create_order(order_data)
    path = '/UT/hs/ice_int/v1/UploadOrder/'
    make_request(path, method: :post, body: order_data)
  end
end

