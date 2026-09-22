# frozen_string_literal: true

require 'httparty'

# Клиент Bot API мессенджера MAX. Наружу отдаёт тот же контракт, что
# SendTelegramMessage (call → объект с success?/error/result) и так же никогда
# не бросает исключений: решение, повторять ли отказ, принимает вызывающий.
class SendMaxMessage
  include HTTParty

  # У MAX в ходу два адреса — botapi.max.ru и platform-api.max.ru, — и способ
  # авторизации у них разный. Держим адрес в переменной окружения, чтобы
  # переезд не требовал выкладки кода.
  base_uri ENV['CLIENT_MAX_API_URL'].presence || 'https://botapi.max.ru'

  # Загруженный файл становится доступным не сразу: несколько секунд MAX
  # отвечает attachment.not.ready. Это не отказ, а «ещё не готово», поэтому
  # ошибка лежит в транзиентных и её повторяет retry_on самой джобы — ждать
  # внутри воркера значило бы держать его занятым ради sleep.
  class AttachmentNotReady < StandardError; end

  TRANSIENT_ERRORS = [
    AttachmentNotReady,
    Net::OpenTimeout, Net::ReadTimeout,
    Errno::ETIMEDOUT, Errno::ECONNRESET, Errno::ECONNREFUSED,
    SocketError
  ].freeze

  JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze

  attr_reader :result, :error, :message_id

  def self.call(**args)
    new(**args).send_message
  end

  def self.transient_error?(error)
    TRANSIENT_ERRORS.any? { |klass| error.is_a?(klass) }
  end

  # photo: открытый File/Tempfile. Картинка уходит вложением, а text —
  # обычным текстом того же сообщения, отдельного метода для неё нет.
  # buttons: массив рядов кнопок; клавиатура — такое же вложение, как картинка.
  def initialize(chat_id:, text:, photo: nil, buttons: nil)
    @chat_id = chat_id
    @text = text
    @photo = photo
    @buttons = buttons
    @result = nil
    @error = nil
    @message_id = nil
  end

  def send_message
    unless token.present?
      @result = 'MAX бот не настроен (нет токена в окружении)'
      return self
    end

    unless @chat_id.present?
      @result = 'MAX chat ID не указан'
      return self
    end

    begin
      deliver(attachments)
    rescue StandardError => e
      Rails.logger.error("[SendMaxMessage] #{e.class}: #{e.message}")
      @error = e
      @result = "Ошибка отправки: #{e.message}"
    end

    self
  end

  def success?
    @result == :success
  end

  private

  # Картинку сперва надо загрузить и получить токен, клавиатуру — просто
  # описать: у MAX это два вложения одного сообщения.
  def attachments
    list = []
    list << upload_photo if @photo
    list << { type: 'inline_keyboard', payload: { buttons: @buttons } } if @buttons.present?
    list
  end

  def token
    ENV['CLIENT_MAX_BOT_TOKEN']
  end

  # chat_id уходит в query, а не в теле — так устроен этот API.
  def deliver(attachments)
    body = { text: @text.to_s }
    body[:attachments] = attachments if attachments.present?

    response = self.class.post('/messages', query: query(chat_id: @chat_id),
                                            body: body.to_json, headers: JSON_HEADERS)

    if response.code == 200
      @message_id = response.dig('message', 'body', 'mid')
      @result = :success
    elsif error_code(response) == 'attachment.not.ready'
      raise AttachmentNotReady, 'вложение ещё не готово на стороне MAX'
    else
      @result = "Ошибка MAX: #{error_text(response)}"
    end
  end

  # Три шага: адрес для загрузки, сама загрузка, токен из ответа. Токен
  # картинки лежит не в корне, а внутри photos под непредсказуемым ключом,
  # поэтому берём первое значение, а не ищем по имени.
  def upload_photo
    response = HTTParty.post(upload_url, body: { data: @photo })
    raise "загрузка файла не удалась (#{response.code})" unless response.code == 200

    photos = response.parsed_response.is_a?(Hash) ? response['photos'] : nil
    photo_token = photos.is_a?(Hash) ? photos.values.first.to_h['token'] : nil
    raise 'MAX не вернул токен загруженной картинки' if photo_token.blank?

    { type: 'image', payload: { token: photo_token } }
  end

  def upload_url
    response = self.class.post('/uploads', query: query(type: 'image'))
    raise "не получен адрес загрузки (#{response.code})" unless response.code == 200 && response['url'].present?

    response['url']
  end

  def query(extra = {})
    { access_token: token }.merge(extra)
  end

  def error_code(response)
    response.parsed_response.is_a?(Hash) ? response['code'] : nil
  end

  def error_text(response)
    body = response.parsed_response
    detail = body.is_a?(Hash) ? (body['message'].presence || body['code'].presence) : nil
    detail || "HTTP #{response.code}"
  end
end
