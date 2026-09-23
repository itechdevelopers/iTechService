# frozen_string_literal: true

# Настройка бота MAX на сервере. Апдейты приходят только тем, кто на них
# подписан, поэтому после первой выкладки подписку надо создать руками —
# отсюда эти задачи, а не «где-то в инициализаторе».
namespace :max_bot do
  desc 'Кем MAX видит нашего бота — проверка токена и адреса API'
  task info: :environment do
    puts "API: #{MaxBotApi.base_uri}"
    puts "токен задан: #{MaxBotApi.configured?}"
    puts MaxWebhook.me.inspect
  end

  desc 'Текущие подписки бота на вебхук'
  task subscriptions: :environment do
    puts MaxWebhook.subscriptions.inspect
  end

  desc 'Подписать бота на вебхук: rake max_bot:subscribe (адрес из SERVER_HOST) или max_bot:subscribe[url]'
  task :subscribe, [:url] => :environment do |_task, args|
    url = args[:url].presence || MaxBotApi.webhook_url
    puts "подписываю на #{url.inspect}, типы: #{MaxWebhook::UPDATE_TYPES.join(', ')}"
    puts MaxWebhook.subscribe(url: url, secret: ENV['CLIENT_MAX_WEBHOOK_SECRET']).inspect
  end

  desc 'Снять подписку: rake max_bot:unsubscribe[url]'
  task :unsubscribe, [:url] => :environment do |_task, args|
    url = args[:url].presence || MaxBotApi.webhook_url
    puts "снимаю подписку с #{url.inspect}"
    puts MaxWebhook.unsubscribe(url: url).inspect
  end
end
