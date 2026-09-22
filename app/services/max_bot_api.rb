# frozen_string_literal: true

# Общая часть всех обращений к Bot API мессенджера MAX: адрес и авторизация.
#
# Вынесено отдельно не ради красоты: у MAX в ходу два хоста с разным способом
# авторизации, и какой из них живой — выяснится на первом настоящем токене.
# Пока этот вопрос открыт, менять его нужно в одном месте, а не в трёх.
module MaxBotApi
  DEFAULT_URL = 'https://botapi.max.ru'
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

  def self.query(extra = {})
    { access_token: token }.merge(extra)
  end

  # Адрес, на который MAX будет слать апдейты. Хост тот же, которым живут
  # ссылки в письмах и уведомлениях.
  def self.webhook_url
    host = ENV['SERVER_HOST'].presence
    host && "https://#{host}#{WEBHOOK_PATH}"
  end
end
