# frozen_string_literal: true

class SendTelegramMessage
  # Transient failures of the channel to api.telegram.org: timeouts of the
  # HTTPClient the telegram-bot gem talks through (HTTPClient::TimeoutError is
  # the parent of the Connect/Send/Receive variants) plus socket-level drops.
  #
  # This service deliberately still swallows them — 17 call sites are written
  # against the "call never raises" contract. Whether a failure is worth a
  # retry is the caller's decision: NotifyEmployeeJob inspects #error and
  # re-raises so its own retry_on can take over.
  TRANSIENT_ERRORS = [
    HTTPClient::TimeoutError,
    Errno::ETIMEDOUT, Errno::ECONNRESET, Errno::ECONNREFUSED,
    SocketError
  ].freeze

  attr_reader :result, :error

  def self.call(**args)
    new(**args).send_message
  end

  def self.transient_error?(error)
    TRANSIENT_ERRORS.any? { |klass| error.is_a?(klass) }
  end

  def initialize(chat_id:, text:)
    @chat_id = chat_id
    @text = text
    @result = nil
    @error = nil
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
      @error = e
      @result = "Ошибка Telegram: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[SendTelegramMessage] Exception: #{e.message}")
      @error = e
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
