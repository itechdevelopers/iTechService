# frozen_string_literal: true

require 'httparty'

module GreenApi
  # Отправка клиенту через инстанс GREEN-API. Наружу отдаёт тот же контракт,
  # что SendMaxMessage и SendTelegramMessage (call → объект с
  # success?/error/result), и так же никогда не бросает исключений: решение,
  # повторять ли отказ, принимает вызывающий.
  class SendMessage
    include HTTParty

    # Отказ, который пройдёт сам: инстанс перезапускается (его перезапускает, в
    # том числе, каждая смена настроек), превышена частота запросов или сбоит
    # связь GREEN-API с мессенджером. Лежит в транзиентных, чтобы его повторил
    # retry_on джобы, а не цикл со sleep внутри воркера.
    class TemporaryFailure < StandardError; end

    TRANSIENT_ERRORS = [
      TemporaryFailure,
      Net::OpenTimeout, Net::ReadTimeout,
      Errno::ETIMEDOUT, Errno::ECONNRESET, Errno::ECONNREFUSED,
      SocketError
    ].freeze

    TEMPORARY_HTTP_CODES = [429, 499, 502, 503, 504].freeze
    # Среди 400-х временный ровно один отказ — инстанс ещё поднимается.
    # Остальные (не авторизован, истёк срок, ошибка валидации) повторять
    # бесполезно.
    STARTING_MARKER = 'starting process'

    OPEN_TIMEOUT = 10
    # Загрузка картинки идёт заметно дольше текстового запроса.
    READ_TIMEOUT = 60

    attr_reader :result, :error, :message_id

    def self.call(**args)
      new(**args).send_message
    end

    def self.transient_error?(error)
      TRANSIENT_ERRORS.any? { |klass| error.is_a?(klass) }
    end

    # photo: открытый File/Tempfile. Текст уходит подписью к картинке, а не
    # отдельным сообщением перед ней.
    def initialize(channel:, chat_id:, text:, photo: nil)
      @channel = Channel.fetch(channel)
      @chat_id = chat_id.to_s
      @text = text.to_s
      @photo = photo
      @result = nil
      @error = nil
      @message_id = nil
    end

    def send_message
      @credentials = @channel.credentials
      unless @credentials.configured?
        @result = "#{@channel.title} не настроен: нет реквизитов инстанса"
        return self
      end

      if @chat_id.blank?
        @result = 'ID чата не указан'
        return self
      end

      begin
        handle(@photo ? post_photo : post_text)
      rescue StandardError => e
        Rails.logger.error("[GreenApi::SendMessage] #{@channel.key}: #{e.class}: #{e.message}")
        @error = e
        @result = "Ошибка отправки: #{e.message}"
      end

      self
    end

    def success?
      @result == :success
    end

    private

    def post_text
      self.class.post(@credentials.method_url('sendMessage'),
                      body: { chatId: @chat_id, message: @text }.to_json,
                      headers: { 'Content-Type' => 'application/json' },
                      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
    end

    # Файл в теле — и HTTParty сам собирает multipart. fileName обязан нести
    # расширение: по нему GREEN-API решает, картинка это или документ.
    #
    # Подпись уходит с бинарной кодировкой: HTTParty склеивает multipart в одну
    # строку, и кириллица в UTF-8 после байтов картинки роняет склейку на
    # Encoding::CompatibilityError. Байты те же — сервер читает их как UTF-8.
    def post_photo
      body = { chatId: @chat_id, file: @photo, fileName: File.basename(@photo.path) }
      body[:caption] = @text.dup.force_encoding(Encoding::BINARY) if @text.present?

      self.class.post(@credentials.method_url('sendFileByUpload', media: true),
                      body: body, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
    end

    def handle(response)
      if response.code == 200 && response_hash(response)['idMessage'].present?
        @message_id = response_hash(response)['idMessage']
        @result = :success
      elsif temporary?(response)
        raise TemporaryFailure, "GREEN-API: #{error_text(response)}"
      else
        @result = "Ошибка GREEN-API: #{error_text(response)}"
      end
    end

    def temporary?(response)
      return true if TEMPORARY_HTTP_CODES.include?(response.code)

      response.code == 400 && error_text(response).include?(STARTING_MARKER)
    end

    def response_hash(response)
      response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    end

    # Тело ошибки у GREEN-API бывает и JSON с message/description, и голым
    # текстом — показываем то, что есть, обрезав на случай HTML-страницы.
    def error_text(response)
      body = response.parsed_response
      detail =
        if body.is_a?(Hash)
          [body['message'], body['description']].reject(&:blank?).join(': ')
        else
          body.to_s.strip[0, 200]
        end
      detail.present? ? "#{detail} (HTTP #{response.code})" : "HTTP #{response.code}"
    end
  end
end
