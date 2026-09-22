# frozen_string_literal: true

require 'httparty'

# Ответ на нажатие кнопки. Пока он не отправлен, у клиента на кнопке крутится
# индикатор — поэтому отвечаем всегда, даже когда сказать нечего.
#
# Адрес и токен читаем так же, как SendMaxMessage: пара сервисов на один
# внешний API уже есть в проекте (SendWhatsapp и CheckWhatsapp), и заводить
# ради двух строк общий базовый класс смысла нет.
class AnswerMaxCallback
  include HTTParty

  base_uri ENV['CLIENT_MAX_API_URL'].presence || 'https://botapi.max.ru'

  JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze

  attr_reader :result

  def self.call(callback_id:, notification: nil)
    new(callback_id: callback_id, notification: notification).answer
  end

  def initialize(callback_id:, notification: nil)
    @callback_id = callback_id
    @notification = notification
    @result = nil
  end

  def answer
    token = ENV['CLIENT_MAX_BOT_TOKEN']
    if token.blank? || @callback_id.blank?
      @result = 'MAX бот не настроен или не передан callback_id'
      return self
    end

    body = @notification.present? ? { notification: @notification } : {}
    response = self.class.post('/answers', query: { access_token: token, callback_id: @callback_id },
                                           body: body.to_json, headers: JSON_HEADERS)

    @result = response.code == 200 ? :success : "Ошибка MAX: HTTP #{response.code}"
    self
  rescue StandardError => e
    Rails.logger.error("[AnswerMaxCallback] #{e.class}: #{e.message}")
    @result = "Ошибка отправки: #{e.message}"
    self
  end

  def success?
    @result == :success
  end
end
