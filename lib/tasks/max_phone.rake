# frozen_string_literal: true

# Настройка канала MAX по номеру на сервере. GREEN-API шлёт уведомления
# только туда, куда указано в настройках инстанса, поэтому после первой
# выкладки их надо прописать руками — отсюда эти задачи.
namespace :max_phone do
  desc 'Реквизиты канала и состояние инстанса (authorized — аккаунт подключён)'
  task info: :environment do
    puts "API: #{MaxPhoneApi.api_url.presence || '—'}, файлы: #{MaxPhoneApi.media_url.presence || '—'}"
    puts "инстанс: #{MaxPhoneApi.instance_id.presence || '—'}, реквизиты заданы: #{MaxPhoneApi.configured?}"
    puts "токен уведомлений задан: #{MaxPhoneApi.webhook_token.present?}"
    puts "состояние: #{MaxPhoneInstance.state.inspect}"
  end

  desc 'Текущие настройки инстанса (токен уведомлений скрыт)'
  task settings: :environment do
    current = MaxPhoneInstance.current_settings
    current['webhookUrlToken'] = '***' if current['webhookUrlToken'].present?
    puts current.inspect
  end

  desc 'Направить уведомления в Айс: rake max_phone:configure (адрес из SERVER_HOST) или max_phone:configure[url]'
  task :configure, [:url] => :environment do |_task, args|
    url = args[:url].presence || MaxPhoneApi.webhook_url
    puts "настраиваю уведомления на #{url.inspect}"
    result = MaxPhoneInstance.configure(webhook_url: url, webhook_token: MaxPhoneApi.webhook_token)
    puts result.inspect
    next unless result['http_code'] == 200

    puts 'GREEN-API применяет настройки в течение 5 минут и при этом перезапускает инстанс'
  end
end
