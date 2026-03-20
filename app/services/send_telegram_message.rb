# frozen_string_literal: true

class SendTelegramMessage
  attr_reader :result

  def self.call(**args)
    new(**args).send_message
  end

  def initialize(chat_id:, text:)
    @chat_id = chat_id
    @text = text
    @result = nil
  end

  def send_message
    unless configured?
      @result = 'Telegram бот не настроен (TELEGRAM_BOT_TOKEN отсутствует)'
      return self
    end

    unless @chat_id.present?
      @result = 'Telegram chat ID не указан'
      return self
    end

    begin
      Telegram.bot.send_message(
        chat_id: @chat_id,
        text: @text,
        parse_mode: 'HTML'
      )
      @result = :success
    rescue Telegram::Bot::Error => e
      Rails.logger.error("[SendTelegramMessage] Telegram API error: #{e.message}")
      @result = "Ошибка Telegram: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[SendTelegramMessage] Exception: #{e.message}")
      @result = "Ошибка отправки: #{e.message}"
    end

    self
  end

  def success?
    @result == :success
  end

  private

  def configured?
    ENV['TELEGRAM_BOT_TOKEN'].present?
  end
end
