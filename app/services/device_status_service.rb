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

  def parse_status(data)
    case data['status']
    when 'Продан', 'Списан'
      item = data['item']
      serial = data['serialnumber']
      date_time = DateTime.parse(data['data'])
      formatted_date = I18n.l(date_time, format: '%d %B %Y года в %H:%M')
      shop = data['shop']
      action = data['status'] == 'Продан' ? 'продано' : 'списано'

      "Устройство #{item} (#{serial}) было #{action} #{formatted_date}. Филиал: #{shop}."
    when 'Принят'
      item = data['item']
      serial = data['serialnumber']

      "Устройство #{item} (#{serial}) было принято."
    when 'Не найден'
      'С таким серийным номером или именем устройство в 1С не найдено.'
    else
      'Неизвестный статус устройства.'
    end
  end
end
