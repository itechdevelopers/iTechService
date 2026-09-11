# frozen_string_literal: true

# Два независимых бота:
#   :default — служебный, привязывает сотрудников и принимает от них медиа
#              (TelegramWebhookController)
#   :client  — публичный, через него пишут клиенты
#              (ClientTelegramWebhookController)
# Каждый поднимается только при своём токене: без него приложение работает,
# просто соответствующий бот не отвечает.
telegram_bots = {
  default: ENV['TELEGRAM_BOT_TOKEN'],
  client: ENV['CLIENT_TELEGRAM_BOT_TOKEN']
}.reject { |_key, token| token.blank? }

if telegram_bots.any?
  Telegram.bots_config = telegram_bots

  # Telegram::Bot::Client строит голый HTTPClient.new, у которого таймаут
  # соединения по умолчанию 60 секунд, и этот клиент общий на все исходящие
  # вызовы бота: respond_with внутри вебхука, get_file при скачивании медиа,
  # личные уведомления. Пока канал до api.telegram.org деградирует, каждый из
  # них висит целую минуту — достаточно, чтобы Telegram счёл вебхук
  # недоставленным и пере-прислал апдейт, и чтобы джоба спалила бюджет ретраев
  # на ожидание вместо повтора.
  #
  # receive_timeout оставлен по умолчанию: send_animation протаскивает через
  # тот же клиент многомегабайтные файлы, ему нужен запас.
  Telegram.bots.each_value { |bot| bot.client.connect_timeout = 10 }
end
