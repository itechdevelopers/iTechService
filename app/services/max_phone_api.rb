# frozen_string_literal: true

# Общая часть обращений к GREEN-API по инстансу MAX: адреса и реквизиты.
#
# Это второй способ переписки в MAX, с ботом не связанный: клиент пишет на
# обычный номер телефона, а GREEN-API подключён к аккаунту этого номера как
# ещё один веб-клиент. Поэтому здесь нет ни токена бота, ни Bot API.
#
# Адресов два: обычные методы ходят на apiUrl, загрузка файлов — на mediaUrl.
# Оба выдаются вместе с инстансом и у разных инстансов различаются, так что
# зашить их в код нельзя.
module MaxPhoneApi
  WEBHOOK_PATH = '/client_max_phone_webhook'

  def self.api_url
    ENV['CLIENT_MAX_PHONE_API_URL'].to_s.chomp('/')
  end

  # Файлы GREEN-API советует грузить через mediaUrl, но принимает и через
  # apiUrl — поэтому без отдельного адреса отправка фото не ломается.
  def self.media_url
    ENV['CLIENT_MAX_PHONE_MEDIA_URL'].to_s.chomp('/').presence || api_url
  end

  def self.instance_id
    ENV['CLIENT_MAX_PHONE_INSTANCE_ID'].to_s
  end

  def self.token
    ENV['CLIENT_MAX_PHONE_API_TOKEN'].to_s
  end

  # Секрет, который GREEN-API кладёт в заголовок Authorization каждого
  # уведомления. Придумываем его мы сами и прописываем в настройки инстанса.
  def self.webhook_token
    ENV['CLIENT_MAX_PHONE_WEBHOOK_TOKEN'].to_s
  end

  def self.configured?
    api_url.present? && instance_id.present? && token.present?
  end

  # Инстанс и токен — части пути, а не заголовки: так устроен весь GREEN-API.
  def self.method_url(name, media: false)
    "#{media ? media_url : api_url}/waInstance#{instance_id}/#{name}/#{token}"
  end

  # Адрес, на который GREEN-API будет слать уведомления. Хост тот же, которым
  # живут ссылки в письмах и уведомлениях.
  def self.webhook_url
    host = ENV['SERVER_HOST'].presence
    host && "https://#{host}#{WEBHOOK_PATH}"
  end
end
