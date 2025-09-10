# frozen_string_literal: true

require 'httparty'

class CheckDeviceStatus
  include HTTParty

  def self.call(**args)
    new(args).call
  end

  def initialize(serial_number:)
    @serial_number = serial_number
    @use_mock = should_use_mock?
    
    if @use_mock
      @mock_service = ::MockOneCService.new
    else
      @auth = { username: ENV['ONE_C_API_USERNAME'], password: ENV['ONE_C_API_PASSWORD'] }
      @base_url = 'http://89.108.120.99:8899'
    end
  end

  def call
    get_status
  end

  def get_status
    if @use_mock
      body = { 'serialnumber' => @serial_number }
      response = @mock_service.make_request('/UT/hs/ice_int/v1/StatusID/', method: :post, body: body)
      
      if response[:success]
        parse_status(response[:data])
      else
        response[:error]
      end
    else
      # Original real 1C service implementation
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
          parse_status(safe_json_parse(response.body))
        else
          "Ошибка при получении данных от 1С. Код ответа: #{response.code}"
        end
      rescue Timeout::Error
        'Сервер 1С не отвечает. Превышено время ожидания.'
      rescue JSON::ParserError => e
        "Ошибка парсинга JSON от 1С: #{e.message}"
      rescue StandardError => e
        "Ошибка при обращении к серверу 1С: #{e.message}"
      end
    end
  end

  private

  def safe_json_parse(response_body)
    # Handle Windows line endings and extra whitespace from 1C server
    cleaned_body = response_body.to_s.strip
    
    begin
      JSON.parse(cleaned_body)
    rescue JSON::ParserError => e
      Rails.logger.error "[CheckDeviceStatus] JSON parsing failed: #{e.message}"
      Rails.logger.error "[CheckDeviceStatus] Raw body: #{response_body.inspect}"
      Rails.logger.error "[CheckDeviceStatus] Cleaned body: #{cleaned_body.inspect}"
      
      # Re-raise the exception to be caught by the outer rescue block
      raise e
    end
  end

  def should_use_mock?
    # Use mock in development environment by default, unless explicitly disabled
    Rails.env.development? && ENV['ONE_C_MOCK_MODE'] != 'false'
  end

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
