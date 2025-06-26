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
      response = self.class.send(method, "#{@base_url}#{path}", options)
      
      if response.code == 200
        { success: true, data: JSON.parse(response.body) }
      else
        { success: false, error: "Ошибка при получении данных от 1С. Код ответа: #{response.code}" }
      end
    rescue Timeout::Error
      { success: false, error: 'Сервер 1С не отвечает. Превышено время ожидания.' }
    rescue StandardError => e
      { success: false, error: "Ошибка при обращении к серверу 1С: #{e.message}" }
    end
  end

  private

  def should_use_mock?
    # Use mock in development environment by default, unless explicitly disabled
    Rails.env.development? && ENV['ONE_C_MOCK_MODE'] != 'false'
  end
end
