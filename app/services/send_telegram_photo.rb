# frozen_string_literal: true

# Отправка фото с подписью через send_photo. От SendTelegramSchedule (base64)
# и SendTelegramAnimation (send_animation) отличается тем, что сохраняет
# пойманное исключение в #error: по нему вызывающая сторона отличает сетевой
# сбой (стоит ретраить) от заблокированного бота (надо отвязать аккаунт).
# Список транзиентных ошибок общий с SendTelegramMessage — канал до
# api.telegram.org один и тот же.
class SendTelegramPhoto
  attr_reader :result, :error

  def self.call(**args)
    new(**args).send_photo
  end

  def initialize(chat_id:, file_path:, caption: nil)
    @chat_id = chat_id
    @file_path = file_path
    @caption = caption
    @result = nil
    @error = nil
  end

  def send_photo
    unless configured?
      @result = 'Telegram бот не настроен (TELEGRAM_BOT_TOKEN отсутствует)'
      return self
    end

    unless @chat_id.present?
      @result = 'Telegram chat ID не указан'
      return self
    end

    unless @file_path.present? && File.exist?(@file_path)
      @result = "Файл изображения не найден: #{@file_path}"
      return self
    end

    file = File.open(@file_path, 'rb')

    begin
      Telegram.bot.send_photo(
        chat_id: @chat_id,
        photo: file,
        caption: @caption,
        parse_mode: 'HTML'
      )
      @result = :success
    rescue Telegram::Bot::Error => e
      Rails.logger.error("[SendTelegramPhoto] Telegram API error: #{e.message}")
      @error = e
      @result = "Ошибка Telegram: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[SendTelegramPhoto] Exception: #{e.message}")
      @error = e
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
