# frozen_string_literal: true

# Общая часть всех обращений к Bot API мессенджера MAX: адрес и авторизация.
#
# Токен передаётся ТОЛЬКО заголовком: на query-параметр access_token API
# отвечает 401 с пометкой deprecated. Официальная python-библиотека MAX всё
# ещё шлёт его параметром — ориентироваться на неё в этом месте нельзя.
module MaxBotApi
  DEFAULT_URL = 'https://platform-api.max.ru'
  WEBHOOK_PATH = '/client_max_webhook'

  def self.base_uri
    ENV['CLIENT_MAX_API_URL'].presence || DEFAULT_URL
  end

  def self.token
    ENV['CLIENT_MAX_BOT_TOKEN']
  end

  def self.configured?
    token.present?
  end

  def self.url(path)
    "#{base_uri}#{path}"
  end

  def self.auth_headers
    { 'Authorization' => token.to_s }
  end

  def self.json_headers
    auth_headers.merge('Content-Type' => 'application/json')
  end

  # Адрес, на который MAX будет слать апдейты. Хост тот же, которым живут
  # ссылки в письмах и уведомлениях.
  def self.webhook_url
    host = ENV['SERVER_HOST'].presence
    host && "https://#{host}#{WEBHOOK_PATH}"
  end
end
