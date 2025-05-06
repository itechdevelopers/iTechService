#frozen_string_literal: true

require 'httparty'

class OneCBaseClient
  include HTTParty

  def initialize
    @auth = { username: ENV['ONE_C_API_USERNAME'], password: ENV['ONE_C_API_PASSWORD'] }
    @base_url = 'http://89.108.120.99:8899'
  end

  protected

  def make_request(path, method: :post, body: nil)
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
end
