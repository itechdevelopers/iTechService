# frozen_string_literal: true

if ENV['TELEGRAM_BOT_TOKEN'].present?
  Telegram.bots_config = { default: ENV['TELEGRAM_BOT_TOKEN'] }

  # Telegram::Bot::Client builds a bare HTTPClient.new, whose default connect
  # timeout is 60 seconds. Every outgoing call shares that single client:
  # respond_with inside the webhook, get_file in TelegramPhotoAttachJob and all
  # personal notifications via SendTelegramMessage. While the channel to
  # api.telegram.org degrades each of them hangs for a full minute — long
  # enough for Telegram to consider the webhook undelivered and re-send the
  # update (duplicate photos), and long enough for a job to burn its retry
  # budget on waiting instead of retrying.
  #
  # receive_timeout is left at the default: send_animation pushes multi-megabyte
  # files through this same client and needs the headroom.
  Telegram.bot.client.connect_timeout = 10
end
