# frozen_string_literal: true

require 'httparty'

class FindMyDeviceCheckService
  API_URL = ENV.fetch('FIND_MY_API_URL', 'https://app.87imei.com/fa396d2dda444de1538e6688a7f4c157/instant/api')
  API_KEY = ENV['FIND_MY_API_KEY']
  SERVICE_ID = ENV.fetch('FIND_MY_SERVICE_ID', '6')
  TIMEOUT = 30

  def self.call(imei:)
    new(imei).call
  end

  def initialize(imei)
    @imei = imei
    @use_mock = Rails.env.development? && ENV['FIND_MY_MOCK_MODE'] != 'false'
  end

  def call
    return { success: false, error: 'API-ключ FIND_MY_API_KEY не настроен' } if !@use_mock && API_KEY.blank?

    if @use_mock
      mock_response
    else
      real_request
    end
  end

  private

  def real_request
    response = HTTParty.get(API_URL, query: {
      key: API_KEY,
      imei: @imei,
      service: SERVICE_ID
    }, timeout: TIMEOUT)

    parse_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout
    { success: false, error: 'Сервис проверки не отвечает. Превышено время ожидания.' }
  rescue StandardError => e
    Rails.logger.error "[FindMyDeviceCheck] Error: #{e.message}"
    { success: false, error: "Ошибка при обращении к сервису проверки: #{e.message}" }
  end

  def parse_response(response)
    unless response.code == 200
      return { success: false, error: "Сервис вернул код #{response.code}" }
    end

    data = response.parsed_response
    data = JSON.parse(data) if data.is_a?(String)

    unless data['success']
      return { success: false, error: data['status'] || 'Неизвестная ошибка сервиса' }
    end

    locked = parse_find_my_status(data['result'])

    {
      success: true,
      locked: locked,
      raw_result: data['result']
    }
  rescue JSON::ParserError => e
    { success: false, error: "Ошибка парсинга ответа: #{e.message}" }
  end

  def parse_find_my_status(result_html)
    return true if result_html.nil?

    result_html.include?('<b>ON</b>')
  end

  def mock_response
    Rails.logger.info "[FindMyDeviceCheck] MOCK: Checking IMEI #{@imei}"
    sleep(rand(0.2..0.5))

    # Even-ending IMEIs = OFF (unlocked), odd = ON (locked)
    locked = @imei.to_s.last.to_i.odd?

    status = locked ? 'ON' : 'OFF'
    color = locked ? 'red' : 'green'

    {
      success: true,
      locked: locked,
      raw_result: "#{@imei} Find My iPhone: <font color=\"#{color}\"><b>#{status}</b></font>"
    }
  end
end
