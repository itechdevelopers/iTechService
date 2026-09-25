#frozen_string_literal: true

class ServiceCheckClient < OneCBaseClient
  def create_check(check_data)
    path = '/UT/hs/ice_int/v2/CreateServiceCheck/'
    make_request(path, method: :post, body: check_data)
  end

  def delete_check(uid)
    path = "/UT/hs/ice_int/v2/DeleteServiceCheck/#{uid}"
    make_request(path, method: :post)
  end

  def find_check(job_number)
    path = "/UT/hs/ice_int/v2/FindServiceCheck/#{job_number}"
    make_request(path, method: :get)
  end
end
