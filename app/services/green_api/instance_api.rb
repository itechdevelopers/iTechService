# frozen_string_literal: true

require 'httparty'

module GreenApi
  # Управление самим инстансом: состояние, аккаунт и настройки уведомлений.
  # Без настроек GREEN-API никуда уведомления не шлёт, и выложенный код
  # молчит.
  #
  # Работает с явно переданными реквизитами, а не с реквизитами канала: перед
  # сохранением новые реквизиты надо проверить, а при смене инстанса —
  # отвязать прежний.
  class InstanceApi
    def self.for(channel, **options)
      new(Channel.fetch(channel).credentials, **options)
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

    # Ответ GREEN-API одной строкой — для сообщения сотруднику.
    def self.failure_text(response)
      return response['error'] if response['error'].present?

      detail = [response['message'], response['description'], response['body']].map(&:to_s).reject(&:blank?).first
      [detail.to_s[0, 200].presence, "HTTP #{response['http_code']}"].compact.join(', ')
    end

    # read_timeout короче для страницы в браузере: лучше показать «не ответил»,
    # чем держать её открытие полминуты.
    def initialize(credentials, read_timeout: 30)
      @credentials = credentials
      @read_timeout = read_timeout
    end

    def state
      request(:get, 'getStateInstance')
    end

    def current_settings
      request(:get, 'getSettings')
    end

    def account(method_name)
      request(:get, method_name)
    end

    # Картинка QR-кода для входа в аккаунт (base64 PNG). Код живёт секунды —
    # его запрашивают снова, пока аккаунт не подключится.
    def qr
      request(:get, 'qr')
    end

    def logout
      request(:get, 'logout')
    end

    def reboot
      request(:get, 'reboot')
    end

    # Облачный пароль аккаунта MAX: после QR-кода, если аккаунт им защищён
    # (состояние pendingPassword).
    def send_password(password)
      request(:post, 'sendAuthorizationPassword', body: { password: password }.to_json,
                                                  headers: { 'Content-Type' => 'application/json' })
    end

    # Токен обязателен: контроллер отвергает уведомления без него, и настройка
    # без токена создала бы мёртвый эндпоинт.
    def configure(webhook_url:, webhook_token:)
      return { 'error' => 'не задан токен уведомлений' } if webhook_token.blank?
      return { 'error' => 'не задан адрес вебхука (SERVER_HOST)' } if webhook_url.blank?

      post_settings(self.class.settings(webhook_url: webhook_url, webhook_token: webhook_token))
    end

    # Инстанс уже настроен как надо — тогда setSettings не зовём: он
    # перезапускает инстанс, и канал на несколько минут замолкает. Адрес и
    # токен обязаны совпасть; прочие флаги сверяем, если GREEN-API их
    # вернул, — у разных мессенджеров набор настроек немного разный.
    def configured_for?(webhook_url:, webhook_token:)
      current = current_settings
      return false unless current['http_code'] == 200

      self.class.settings(webhook_url: webhook_url, webhook_token: webhook_token).all? do |name, value|
        required = %i[webhookUrl webhookUrlToken].include?(name)
        (!required && !current.key?(name.to_s)) || current[name.to_s].to_s == value.to_s
      end
    end

    # Направить уведомления в Айс, если они ещё идут не туда. Возвращает
    # [:already | :applied | :failed, текст отказа]: после :applied GREEN-API
    # ещё до пяти минут применяет настройки.
    def ensure_webhook(webhook_url:, webhook_token:)
      return [:already, nil] if webhook_url.present? && configured_for?(webhook_url: webhook_url, webhook_token: webhook_token)

      response = configure(webhook_url: webhook_url, webhook_token: webhook_token)
      response['http_code'] == 200 ? [:applied, nil] : [:failed, self.class.failure_text(response)]
    end

    # Прежний инстанс перестаёт слать нам уведомления. Их и так отвергнет
    # сверка номера инстанса, но GREEN-API повторял бы каждое ещё сутки.
    def detach
      post_settings(webhookUrl: '')
    end

    private

    def post_settings(settings)
      request(:post, 'setSettings', body: settings.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    def request(method, name, **options)
      return { 'error' => 'не заданы реквизиты инстанса' } unless @credentials.configured?

      response = HTTParty.send(method, @credentials.method_url(name),
                               options.merge(open_timeout: 10, read_timeout: @read_timeout))
      body = response.parsed_response
      body.is_a?(Hash) ? body.merge('http_code' => response.code) : { 'body' => body, 'http_code' => response.code }
    rescue StandardError => e
      { 'error' => "#{e.class}: #{e.message}" }
    end
  end
end
