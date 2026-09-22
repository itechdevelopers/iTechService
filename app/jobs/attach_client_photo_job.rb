# frozen_string_literal: true

require 'open-uri'
require 'tempfile'
require 'excon' # fog-aws грузит через excon, его сетевые ошибки ретраим

# Скачивает фото, присланное клиентом в бот, и прикладывает к уже созданной
# записи ленты. Строку ClientMessage создаёт вебхук — сотрудник видит реплику
# сразу, а картинка догружается: два обращения к сети (мессенджер и хранилище)
# внутри вебхука заняли бы больше, чем мессенджер готов ждать ответа.
#
# Второй аргумент канально-зависим: у Telegram это file_id, у MAX — готовая
# ссылка. Разбирается в адаптере, сюда возвращается уже адрес файла.
class AttachClientPhotoJob < ApplicationJob
  queue_as :default

  # Сетевые сбои на обоих плечах: api.telegram.org (HTTPClient в геме и
  # open-uri для самого файла) и хранилище (excon под fog-aws).
  TRANSIENT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout,
                      Errno::ETIMEDOUT, Errno::ECONNRESET, SocketError,
                      HTTPClient::TimeoutError,
                      Excon::Error::Timeout, Excon::Error::Socket].freeze
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  # Объявлен ДО retry_on намеренно: Rails подбирает обработчик, обходя список
  # с конца, поэтому объявленные ниже retry_on разбирают свои классы первыми, а
  # сюда попадает только то, что не подошло никому. Поставить этот catch-all
  # после них — значит проглотить и транзиентные ошибки, отключив ретраи.
  #
  # Не пробрасываем наружу: иначе джоб уходит в собственную политику Sidekiq
  # (25 попыток на три недели), и фото может всплыть через неделю после того,
  # как клиенту уже ответили.
  rescue_from(StandardError) do |error|
    Rails.logger.error("[AttachClientPhotoJob] непредвиденный сбой: #{error.class}: #{error.message}")
  end

  TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 4 do |job, error|
      # error_label, а не error.message: на Rails 5.1 сюда приходит класс.
      Rails.logger.error("[AttachClientPhotoJob] giving up for message " \
                         "#{job.arguments.first}: #{job.send(:error_label, error)}")
    end
  end

  def perform(message_id, file_ref)
    message = ClientMessage.find_by(id: message_id)
    return if message.nil? || message.photo?

    url = ClientMessenger.for(message.conversation).photo_url(file_ref)
    return if url.blank?

    tempfile = fetch(url, extension_of(url))
    return if tempfile.nil?

    message.photo = tempfile
    message.save!
    # Реплика уже в ленте с пометкой «загружается» — досылаем её же, чтобы
    # открытая карточка подменила пометку картинкой.
    ClientConversationChannel.broadcast_message(message)
  ensure
    tempfile&.close!
  end

  private

  # Расширение нужно временному файлу: по нему CarrierWave и хранилище
  # определяют тип картинки. В ссылке может быть query-строка, поэтому берём
  # только путь.
  def extension_of(url)
    File.extname(URI.parse(url).path).presence || '.jpg'
  rescue URI::InvalidURIError
    '.jpg'
  end

  def fetch(url, ext)
    tempfile = Tempfile.new(['client_photo', ext])
    tempfile.binmode
    URI.open(url, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |remote|
      IO.copy_stream(remote, tempfile)
    end
    tempfile.rewind
    tempfile
  rescue *TRANSIENT_ERRORS
    tempfile&.close!
    raise # пусть retry_on повторит с задержкой
  rescue StandardError => e
    Rails.logger.error("[AttachClientPhotoJob] скачивание не удалось: #{e.class}: #{e.message}")
    tempfile&.close!
    nil
  end
end
