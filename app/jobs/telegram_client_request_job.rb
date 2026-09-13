# frozen_string_literal: true

# Один исходящий вызов Telegram, вынесенный из обработчика вебхука/поллера.
#
# Гем умеет делать это сам (`bot.async(true)`), но создаёт класс джобы
# динамически и лениво — в процессе Sidekiq константы может не оказаться, и
# задача упадёт на десериализации. Поэтому класс объявлен явно.
class TelegramClientRequestJob < ApplicationJob
  include Telegram::Bot::Async::Job

  self.client_class = Telegram::Bot::Client

  queue_as :default

  # Канал до api.telegram.org с этого сервера рвётся примерно в одном случае
  # из двадцати. Здесь это стоит нескольких секунд ретрая — в отличие от
  # обработчика вебхука, где тот же сбой оборачивался 500 и переприсылкой
  # апдейта с нарастающей паузой.
  SendTelegramMessage::TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 5 do |job, error|
      # error_label, а не error.message: на Rails 5.1 сюда приходит класс.
      Rails.logger.error("[TelegramClientRequestJob] не отправлено: #{job.send(:error_label, error)}")
    end
  end
end
