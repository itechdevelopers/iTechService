# frozen_string_literal: true

module ClientMessenger
  # Доставка в MAX по номеру телефона, через GREEN-API. Устроен как адаптер
  # бота MAX: наружу отдаёт сам клиент отправки, его контракта
  # success?/error/result джобе достаточно.
  class MaxPhoneAdapter
    TRANSIENT_ERRORS = SendMaxPhoneMessage::TRANSIENT_ERRORS

    def self.transient_error?(error)
      SendMaxPhoneMessage.transient_error?(error)
    end

    def deliver(message)
      return send_message(message, text: message.body) unless message.photo?

      ClientMessenger.with_photo_tempfile(message) do |file|
        send_message(message, text: message.body.to_s, photo: file)
      end
    end

    # GREEN-API кладёт в уведомление прямую ссылку на файл, резолвить нечего.
    def photo_url(url)
      url.presence
    end

    private

    def send_message(message, text:, photo: nil)
      SendMaxPhoneMessage.call(chat_id: message.conversation.external_chat_id, text: text, photo: photo)
    end
  end
end
