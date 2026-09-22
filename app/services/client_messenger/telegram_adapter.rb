# frozen_string_literal: true

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

    def deliver_photo(message)
      ClientMessenger.with_photo_tempfile(message) do |file|
        send_message(message, text: message.body.to_s, photo: file)
      end
    end

    def send_message(message, text:, photo: nil)
      SendTelegramMessage.call(chat_id: message.conversation.external_chat_id, text: text,
                               bot: :client, parse_mode: nil, photo: photo)
    end
  end
end
