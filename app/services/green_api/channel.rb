# frozen_string_literal: true

module GreenApi
  # Канал переписки с клиентами поверх инстанса GREEN-API. Протокол у GREEN-API
  # для всех мессенджеров один (API для MAX повторяет WhatsApp-API вплоть до
  # waInstance в адресе), поэтому каналы различаются только реквизитами
  # инстанса и адресом, на который он шлёт уведомления.
  class Channel
    attr_reader :key, :webhook_path, :account_method

    def self.fetch(key)
      REGISTRY.fetch(key.to_s)
    end

    def self.all
      REGISTRY.values
    end

    # account_method — метод GREEN-API с номером и состоянием аккаунта: у
    # каждого мессенджера он свой. env_prefix — у канала, реквизиты которого
    # жили в окружении сервера до того, как их стали вводить в Айсе.
    def initialize(key:, webhook_path:, account_method:, env_prefix: nil)
      @key = key
      @webhook_path = webhook_path
      @account_method = account_method
      @env_prefix = env_prefix
    end

    def title
      I18n.t("client_conversations.conversation.channels.#{key}", default: key)
    end

    def instance_record
      GreenApiInstance.find_by(channel: key)
    end

    # Введённое в Айсе главнее окружения: окружение читается, только пока
    # инстанс в Айсе не сохранён, — так выкладка не ломает работающий канал.
    def credentials
      instance_record&.credentials || env_credentials
    end

    def env_credentials
      return Credentials.new(api_url: '', media_url: '', instance_id: '', token: '', webhook_token: '', source: :none) if @env_prefix.nil?

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
      'max_phone' => new(key: 'max_phone', webhook_path: '/client_max_phone_webhook',
                         account_method: 'getAccountSettings', env_prefix: 'CLIENT_MAX_PHONE')
    }.freeze
  end
end
