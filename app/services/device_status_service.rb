#frozen_string_literal: true

class DeviceStatusService < OneCBaseClient
  def self.call(**args)
    new.check_status(args[:serial_number])
  end

  def check_status(serial_number)
    response = make_request('/UT/hs/ice_int/v1/StatusID/',
                            body: { serial_number: serial_number })

    if response[:success]
      parse_status(response[:data])
    else
      response[:error]
    end
  end

  private
end
