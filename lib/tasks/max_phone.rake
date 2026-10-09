# frozen_string_literal: true

# Настройка каналов GREEN-API на сервере. GREEN-API шлёт уведомления только
# туда, куда указано в настройках инстанса, поэтому после подключения
# инстанса их надо прописать — отсюда эти задачи.
%w[max_phone].each do |key|
  namespace key do
    desc "#{key}: реквизиты канала и состояние инстанса (authorized — аккаунт подключён)"
    task info: :environment do
      credentials = GreenApi::Channel.fetch(key).credentials
      puts "API: #{credentials.api_url.presence || '—'}, файлы: #{credentials.media_url.presence || '—'}"
      puts "инстанс: #{credentials.instance_id.presence || '—'}, реквизиты заданы: #{credentials.configured?}"
      puts "токен уведомлений задан: #{credentials.webhook_token.present?}"
      puts "состояние: #{GreenApi::InstanceApi.for(key).state.inspect}"
    end

    desc "#{key}: текущие настройки инстанса (токен уведомлений скрыт)"
    task settings: :environment do
      current = GreenApi::InstanceApi.for(key).current_settings
      current['webhookUrlToken'] = '***' if current['webhookUrlToken'].present?
      puts current.inspect
    end

    desc "#{key}: направить уведомления в Айс — rake #{key}:configure (адрес из SERVER_HOST) или #{key}:configure[url]"
    task :configure, [:url] => :environment do |_task, args|
      channel = GreenApi::Channel.fetch(key)
      url = args[:url].presence || channel.webhook_url
      puts "настраиваю уведомления на #{url.inspect}"
      result = GreenApi::InstanceApi.for(key).configure(webhook_url: url,
                                                        webhook_token: channel.credentials.webhook_token)
      puts result.inspect
      next unless result['http_code'] == 200

      puts 'GREEN-API применяет настройки в течение 5 минут и при этом перезапускает инстанс'
    end
  end
end
