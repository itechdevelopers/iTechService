# frozen_string_literal: true

class SendTelegramSchedule
  attr_reader :result

  def self.call(**args)
    new(**args).send_schedule
  end

  def initialize(chat_id:, image_data:, caption: nil)
    @chat_id = chat_id
    @image_data = image_data
    @caption = caption
    @result = nil
  end

  def send_schedule
    unless configured?
      @result = 'Telegram бот не настроен (TELEGRAM_BOT_TOKEN отсутствует)'
      return self
    end

    unless @chat_id.present?
      @result = 'Telegram chat ID не указан'
      return self
    end

    image_binary = Base64.decode64(@image_data)

    tempfile = Tempfile.new(['schedule', '.png'])
    tempfile.binmode
    tempfile.write(image_binary)
    tempfile.rewind

    begin
      Telegram.bot.send_photo(
        chat_id: @chat_id,
        photo: tempfile,
        caption: @caption
      )
      @result = :success
    rescue Telegram::Bot::Error => e
      Rails.logger.error("[SendTelegramSchedule] Telegram API error: #{e.message}")
      @result = "Ошибка Telegram: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[SendTelegramSchedule] Exception: #{e.message}")
      @result = "Ошибка отправки: #{e.message}"
    ensure
      tempfile.close
      tempfile.unlink
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
