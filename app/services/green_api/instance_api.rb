# frozen_string_literal: true

require 'httparty'

module GreenApi
  # Управление самим инстансом: состояние и настройки уведомлений. Без
  # настроек GREEN-API никуда уведомления не шлёт, и выложенный код молчит.
  class InstanceApi
    def initialize(channel)
      @channel = Channel.fetch(channel)
    end

    # Ровно то, что разбирает контроллер, плюс состояние аккаунта для лога.
    # Свои же ответы из Айса (outgoingAPIMessageWebhook) не запрашиваем: они уже
    # в ленте. Правки и удаления сообщений мы не показываем.
    #
    # markIncomingMessagesReaded выключен, чтобы клиент не видел «прочитано»,
    # пока сообщение никто не открыл; отметка появится вместе с ответом.
    def self.settings(webhook_url:, webhook_token:)
      {
        webhookUrl: webhook_url,
        webhookUrlToken: webhook_token,
        incomingWebhook: 'yes',
        outgoingMessageWebhook: 'yes',
        outgoingWebhook: 'yes',
        outgoingAPIMessageWebhook: 'no',
        stateWebhook: 'yes',
        editedMessageWebhook: 'no',
        deletedMessageWebhook: 'no',
        pollMessageWebhook: 'no',
        markIncomingMessagesReaded: 'no',
        markIncomingMessagesReadedOnReply: 'yes'
      }
    end

    def state
      request(:get, 'getStateInstance')
    end

    def current_settings
      request(:get, 'getSettings')
    end

    # Токен обязателен: контроллер отвергает уведомления без него, и настройка
    # без токена создала бы мёртвый эндпоинт.
    def configure(webhook_url:, webhook_token:)
      return { 'error' => 'не задан токен уведомлений' } if webhook_token.blank?
      return { 'error' => 'не задан адрес вебхука' } if webhook_url.blank?

      request(:post, 'setSettings',
              body: self.class.settings(webhook_url: webhook_url, webhook_token: webhook_token).to_json,
              headers: { 'Content-Type' => 'application/json' })
    end

    private

    def request(method, name, **options)
      credentials = @channel.credentials
      return { 'error' => 'не заданы реквизиты инстанса' } unless credentials.configured?

      response = HTTParty.send(method, credentials.method_url(name),
                               options.merge(open_timeout: 10, read_timeout: 30))
      body = response.parsed_response
      body.is_a?(Hash) ? body.merge('http_code' => response.code) : { 'body' => body, 'http_code' => response.code }
    rescue StandardError => e
      { 'error' => "#{e.class}: #{e.message}" }
    end
  end
end
