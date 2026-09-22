# frozen_string_literal: true

require 'httparty'

# Управление подпиской бота на вебхук: без неё MAX просто никуда не шлёт
# апдейты, и выложенный код молчит.
#
# Живёт отдельно от отправки сообщений, потому что зовётся не приложением, а
# человеком при выкладке — через rake max_bot:*.
module MaxWebhook
  # Ровно то, что разбирает контроллер. Лишние типы не запрашиваем: каждый
  # апдейт, который мы не обрабатываем, — это впустую разбуженный воркер.
  UPDATE_TYPES = %w[message_created bot_started bot_stopped message_callback].freeze

  JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze

  def self.me
    request(:get, '/me')
  end

  def self.subscriptions
    request(:get, '/subscriptions')
  end

  # secret обязателен: контроллер отвергает запросы без совпадающего заголовка,
  # поэтому подписка без секрета создала бы мёртвый эндпоинт.
  def self.subscribe(url:, secret:)
    return { 'error' => 'не задан секрет (CLIENT_MAX_WEBHOOK_SECRET)' } if secret.blank?
    return { 'error' => 'не задан адрес вебхука' } if url.blank?

    request(:post, '/subscriptions',
            body: { url: url, secret: secret, update_types: UPDATE_TYPES }.to_json,
            headers: JSON_HEADERS)
  end

  def self.unsubscribe(url:)
    request(:delete, '/subscriptions', query_extra: { url: url })
  end

  def self.request(method, path, query_extra: {}, **options)
    return { 'error' => 'не задан токен (CLIENT_MAX_BOT_TOKEN)' } unless MaxBotApi.configured?

    response = HTTParty.send(method, MaxBotApi.url(path),
                             { query: MaxBotApi.query(query_extra) }.merge(options))
    body = response.parsed_response
    body.is_a?(Hash) ? body.merge('http_code' => response.code) : { 'body' => body, 'http_code' => response.code }
  rescue StandardError => e
    { 'error' => "#{e.class}: #{e.message}" }
  end
  private_class_method :request
end
