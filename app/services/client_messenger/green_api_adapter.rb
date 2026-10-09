# frozen_string_literal: true

module ClientMessenger
  # Доставка через инстанс GREEN-API. Каналы-наследники задают только CHANNEL:
  # протокол у GREEN-API один на все мессенджеры. Наружу отдаёт сам клиент
  # отправки, его контракта success?/error/result джобе достаточно.
  class GreenApiAdapter
    TRANSIENT_ERRORS = GreenApi::SendMessage::TRANSIENT_ERRORS

    def self.transient_error?(error)
      GreenApi::SendMessage.transient_error?(error)
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
      GreenApi::SendMessage.call(channel: self.class::CHANNEL, chat_id: message.conversation.external_chat_id,
                                 text: text, photo: photo)
    end
  end
end
