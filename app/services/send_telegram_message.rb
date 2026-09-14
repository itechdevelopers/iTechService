# frozen_string_literal: true

class SendTelegramMessage
  # Transient failures of the channel to api.telegram.org: timeouts of the
  # HTTPClient the telegram-bot gem talks through (HTTPClient::TimeoutError is
  # the parent of the Connect/Send/Receive variants) plus socket-level drops.
  #
  # This service deliberately still swallows them — 17 call sites are written
  # against the "call never raises" contract. Whether a failure is worth a
  # retry is the caller's decision: NotifyEmployeeJob inspects #error and
  # re-raises so its own retry_on can take over.
  TRANSIENT_ERRORS = [
    HTTPClient::TimeoutError,
    Errno::ETIMEDOUT, Errno::ECONNRESET, Errno::ECONNREFUSED,
    SocketError
  ].freeze

  attr_reader :result, :error

  def self.call(**args)
    new(**args).send_message
  end

  def self.transient_error?(error)
    TRANSIENT_ERRORS.any? { |klass| error.is_a?(klass) }
  end

  # bot: ключ из Telegram.bots_config. :default — служебный бот, :client —
  # публичный, через который идёт переписка с клиентами.
  #
  # parse_mode: 'HTML' безопасен, пока текст пишем мы сами. Для ответа клиенту
  # его нужно снимать (parse_mode: nil): текст печатает живой сотрудник, и
  # любое «цена < 5000» Telegram отвергнет как незакрытый тег — сообщение
  # не уйдёт, хотя выглядеть будет отправленным.
  # photo: открытый File/IO. Тогда уходит sendPhoto, а text становится
  # подписью — у Telegram это разные методы, но для вызывающего это по-прежнему
  # «отправить сообщение в чат».
  def initialize(chat_id:, text:, bot: :default, parse_mode: 'HTML', photo: nil)
    @chat_id = chat_id
    @text = text
    @bot = bot
    @parse_mode = parse_mode
    @photo = photo
    @result = nil
    @error = nil
  end

  def send_message
    unless client
      @result = "Telegram бот :#{@bot} не настроен (нет токена в окружении)"
      return self
    end

    unless @chat_id.present?
      @result = 'Telegram chat ID не указан'
      return self
    end

    begin
      @photo ? client.send_photo(photo_params) : client.send_message(message_params)
      @result = :success
    rescue Telegram::Bot::Error => e
      Rails.logger.error("[SendTelegramMessage] Telegram API error: #{e.message}")
      @error = e
      @result = "Ошибка Telegram: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[SendTelegramMessage] Exception: #{e.message}")
      @error = e
      @result = "Ошибка отправки: #{e.message}"
    end

    self
  end

  def success?
    @result == :success
  end

  private

  def client
    return @client if defined?(@client)

    @client = Telegram.bots[@bot]
  end

  # parse_mode кладём в запрос только когда он задан: с nil Telegram получил бы
  # пустой режим разбора вместо обычного текста.
  def message_params
    params = { chat_id: @chat_id, text: @text }
    params[:parse_mode] = @parse_mode if @parse_mode.present?
    params
  end

  def photo_params
    params = { chat_id: @chat_id, photo: @photo }
    params[:caption] = @text if @text.present?
    params[:parse_mode] = @parse_mode if @parse_mode.present? && @text.present?
    params
  end
end
