# frozen_string_literal: true

require 'httparty'

class CheckDeviceStatus
  include HTTParty

  def self.call(**args)
    new(args).call
  end

  def initialize(serial_number:)
    @serial_number = serial_number
    @auth = { username: ENV['1C_API_USERNAME'], password: ENV['1C_API_PASSWORD'] }
    @base_url = 'http://89.108.120.99:8899'
  end

  def call
    get_status
  end

  def get_status
    options = {
      body: { serialnumber: @serial_number }.to_json,
      basic_auth: @auth,
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      verify: false
    }

    begin
      response = self.class.post("#{@base_url}/UT/hs/ice_int/v1/StatusID/", options)

      if response.code == 200
        parse_status(JSON.parse(response.body))
      else
        "Ошибка при получении данных от 1С. Код ответа: #{response.code}"
      end
    rescue Timeout::Error
      'Сервер 1С не отвечает. Превышено время ожидания.'
    rescue StandardError => e
      "Ошибка при обращении к серверу 1С: #{e.message}"
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
