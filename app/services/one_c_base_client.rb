#frozen_string_literal: true

require 'httparty'

class OneCBaseClient
  include HTTParty

  def initialize
    @use_mock = should_use_mock?
    
    if @use_mock
      @mock_service = ::MockOneCService.new
    else
      @auth = { username: ENV['ONE_C_API_USERNAME'], password: ENV['ONE_C_API_PASSWORD'] }
      @base_url = 'http://89.108.120.99:8899'
      Rails.logger.info '[1C] Using real 1C service'
    end
  end

  protected

  def make_request(path, method: :post, body: nil)
    if @use_mock
      return @mock_service.make_request(path, method: method, body: body)
    end

    # Original real 1C service implementation
    options = {
      basic_auth: @auth,
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      verify: false
    }

    options[:body] = body.to_json if body

    begin
      # Log request details
      Rails.logger.info "[1C Debug] Request: #{method.upcase} #{@base_url}#{path}"
      Rails.logger.info "[1C Debug] Request body: #{body&.to_json}"
      
      response = self.class.send(method, "#{@base_url}#{path}", options)
      
      # Log response details
      Rails.logger.info "[1C Debug] Response code: #{response.code}"
      Rails.logger.info "[1C Debug] Response headers: #{response.headers.inspect}"
      Rails.logger.info "[1C Debug] Raw response body: #{response.body}"
      
      parsed_response = nil
      if response.code == 200
        parsed_response = { success: true, data: JSON.parse(response.body) }
      elsif response.code == 500 && (path.include?('/UploadOrder/') || path.include?('/UpdateOrder/'))
        # 500 from creation/update endpoints still contains JSON with business logic errors
        parsed_response = { success: true, data: JSON.parse(response.body) }
      else
        parsed_response = { success: false, error: "Ошибка при получении данных от 1С. Код ответа: #{response.code}" }
      end
      
      Rails.logger.info "[1C Debug] Parsed response: #{parsed_response.inspect}"
      parsed_response
    rescue Timeout::Error => e
      error_response = { success: false, error: 'Сервер 1С не отвечает. Превышено время ожидания.' }
      Rails.logger.error "[1C Debug] Timeout error: #{e.message}"
      Rails.logger.info "[1C Debug] Error response: #{error_response.inspect}"
      error_response
    rescue StandardError => e
      error_response = { success: false, error: "Ошибка при обращении к серверу 1С: #{e.message}" }
      Rails.logger.error "[1C Debug] Standard error: #{e.class.name} - #{e.message}"
      Rails.logger.error "[1C Debug] Error backtrace: #{e.backtrace.first(5).join(', ')}"
      Rails.logger.info "[1C Debug] Error response: #{error_response.inspect}"
      error_response
    end
  end

  private

  def should_use_mock?
    # Use mock in development environment by default, unless explicitly disabled
    Rails.env.development? && ENV['ONE_C_MOCK_MODE'] != 'false'
  end
end
