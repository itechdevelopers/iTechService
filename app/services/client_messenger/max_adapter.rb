# frozen_string_literal: true

module ClientMessenger
  # Доставка в MAX. Как и телеграмный, отдаёт наружу сам клиент: контракт
  # success?/error/result у них общий, и джобе больше ничего не нужно.
  class MaxAdapter
    TRANSIENT_ERRORS = SendMaxMessage::TRANSIENT_ERRORS

    def self.transient_error?(error)
      SendMaxMessage.transient_error?(error)
    end

    def deliver(message)
      return send_message(message, text: message.body) unless message.photo?

      ClientMessenger.with_photo_tempfile(message) do |file|
        send_message(message, text: message.body.to_s, photo: file)
      end
    end

    # MAX кладёт в апдейт прямую ссылку на файл, резолвить нечего.
    def photo_url(url)
      url.presence
    end

    private

    def send_message(message, text:, photo: nil)
      SendMaxMessage.call(chat_id: message.conversation.external_chat_id, text: text, photo: photo)
    end
  end
end
