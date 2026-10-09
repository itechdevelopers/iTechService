# frozen_string_literal: true

module GreenApi
  # Канал переписки с клиентами поверх инстанса GREEN-API. Протокол у GREEN-API
  # для всех мессенджеров один (API для MAX повторяет WhatsApp-API вплоть до
  # waInstance в адресе), поэтому каналы различаются только реквизитами
  # инстанса и адресом, на который он шлёт уведомления.
  class Channel
    attr_reader :key, :webhook_path

    def self.fetch(key)
      REGISTRY.fetch(key.to_s)
    end

    def initialize(key:, webhook_path:, env_prefix:)
      @key = key
      @webhook_path = webhook_path
      @env_prefix = env_prefix
    end

    def title
      I18n.t("client_conversations.conversation.channels.#{key}", default: key)
    end

    def credentials
      Credentials.new(api_url: env('API_URL').chomp('/'), media_url: env('MEDIA_URL').chomp('/'),
                      instance_id: env('INSTANCE_ID'), token: env('API_TOKEN'),
                      webhook_token: env('WEBHOOK_TOKEN'), source: :env)
    end

    # Хост тот же, которым живут ссылки в письмах и уведомлениях.
    def webhook_url
      host = ENV['SERVER_HOST'].presence
      host && "https://#{host}#{webhook_path}"
    end

    private

    def env(name)
      ENV["#{@env_prefix}_#{name}"].to_s
    end

    REGISTRY = {
      'max_phone' => new(key: 'max_phone', webhook_path: '/client_max_phone_webhook', env_prefix: 'CLIENT_MAX_PHONE')
    }.freeze
  end
end
