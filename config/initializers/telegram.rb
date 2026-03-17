# frozen_string_literal: true

if ENV['TELEGRAM_BOT_TOKEN'].present?
  Telegram.bots_config = { default: ENV['TELEGRAM_BOT_TOKEN'] }
end
