# frozen_string_literal: true

require 'httparty'

# Настройка инстанса GREEN-API под канал MAX по номеру: куда слать
# уведомления и какие. Без этого GREEN-API никуда их не шлёт, и выложенный
# код молчит.
#
# Живёт отдельно от отправки сообщений, потому что зовётся не приложением, а
# человеком при выкладке — через rake max_phone:*.
module MaxPhoneInstance
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

  def self.state
    request(:get, 'getStateInstance')
  end

  def self.current_settings
    request(:get, 'getSettings')
  end

  # Токен обязателен: контроллер отвергает уведомления без него, и настройка
  # без токена создала бы мёртвый эндпоинт.
  def self.configure(webhook_url:, webhook_token:)
    return { 'error' => 'не задан токен уведомлений (CLIENT_MAX_PHONE_WEBHOOK_TOKEN)' } if webhook_token.blank?
    return { 'error' => 'не задан адрес вебхука' } if webhook_url.blank?

    request(:post, 'setSettings',
            body: settings(webhook_url: webhook_url, webhook_token: webhook_token).to_json,
            headers: { 'Content-Type' => 'application/json' })
  end

  def self.request(method, name, **options)
    return { 'error' => 'не заданы реквизиты инстанса (CLIENT_MAX_PHONE_*)' } unless MaxPhoneApi.configured?

    response = HTTParty.send(method, MaxPhoneApi.method_url(name),
                             options.merge(open_timeout: 10, read_timeout: 30))
    body = response.parsed_response
    body.is_a?(Hash) ? body.merge('http_code' => response.code) : { 'body' => body, 'http_code' => response.code }
  rescue StandardError => e
    { 'error' => "#{e.class}: #{e.message}" }
  end
  private_class_method :request
end
