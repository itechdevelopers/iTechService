# frozen_string_literal: true

require 'tempfile'

module ClientMessenger
  # Доставка в Telegram. Возвращает наружу сам SendTelegramMessage: у него уже
  # есть контракт success?/error/result, которого достаточно джобе, и городить
  # поверх свой объект-обёртку незачем.
  class TelegramAdapter
    TRANSIENT_ERRORS = SendTelegramMessage::TRANSIENT_ERRORS

    def self.transient_error?(error)
      SendTelegramMessage.transient_error?(error)
    end

    def deliver(message)
      message.photo? ? deliver_photo(message) : deliver_text(message)
    end

    private

    def deliver_text(message)
      send_message(message, text: message.body)
    end

    # Файл лежит в облаке, а гем принимает открытый File — поэтому сначала
    # выкачиваем во временный. Ссылкой не отдаём: бакет приватный, и полагаться
    # на то, что Telegram до него дотянется, нельзя.
    def deliver_photo(message)
      tempfile = Tempfile.new(['client_out', File.extname(message.photo.path.to_s).presence || '.jpg'])
      tempfile.binmode
      tempfile.write(message.photo.file.read)
      tempfile.rewind

      send_message(message, text: message.body.to_s, photo: tempfile)
    ensure
      tempfile&.close!
    end

    def send_message(message, text:, photo: nil)
      SendTelegramMessage.call(chat_id: message.conversation.external_chat_id, text: text,
                               bot: :client, parse_mode: nil, photo: photo)
    end
  end
end
