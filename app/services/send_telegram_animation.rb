# frozen_string_literal: true

# Отправка анимации (GIF/MP4) в Telegram-чат через send_animation.
# Аналог SendTelegramSchedule (тот шлёт send_photo), но принимает путь к файлу
# на диске (CarrierWave хранит файл локально) — без base64.
class SendTelegramAnimation
  attr_reader :result

  def self.call(**args)
    new(**args).send_animation
  end

  def initialize(chat_id:, file_path:, caption: nil)
    @chat_id = chat_id
    @file_path = file_path
    @caption = caption
    @result = nil
  end

  def send_animation
    unless configured?
      @result = 'Telegram бот не настроен (TELEGRAM_BOT_TOKEN отсутствует)'
      return self
    end

    unless @chat_id.present?
      @result = 'Telegram chat ID не указан'
      return self
    end

    unless @file_path.present? && File.exist?(@file_path)
      @result = 'Файл анимации не найден'
      return self
    end

    file = File.open(@file_path, 'rb')

    begin
      Telegram.bot.send_animation(
        chat_id: @chat_id,
        animation: file,
        caption: @caption
      )
      @result = :success
    rescue Telegram::Bot::Error => e
      Rails.logger.error("[SendTelegramAnimation] Telegram API error: #{e.message}")
      @result = "Ошибка Telegram: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[SendTelegramAnimation] Exception: #{e.message}")
      @result = "Ошибка отправки: #{e.message}"
    ensure
      file.close
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
