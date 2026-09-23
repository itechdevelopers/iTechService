# frozen_string_literal: true

require 'httparty'

# Ответ на нажатие кнопки. Пока он не отправлен, у клиента на кнопке крутится
# индикатор — поэтому отвечаем всегда, даже когда сказать нечего.
#
# Адрес и авторизация — общие для всех обращений к MAX, они в MaxBotApi.
class AnswerMaxCallback
  include HTTParty

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
    if !MaxBotApi.configured? || @callback_id.blank?
      @result = 'MAX бот не настроен или не передан callback_id'
      return self
    end

    body = @notification.present? ? { notification: @notification } : {}
    response = self.class.post(MaxBotApi.url('/answers'), query: { callback_id: @callback_id },
                               body: body.to_json, headers: MaxBotApi.json_headers)

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
