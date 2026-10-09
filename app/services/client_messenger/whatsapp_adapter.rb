# frozen_string_literal: true

module ClientMessenger
  # WhatsApp по номеру телефона, через GREEN-API.
  class WhatsappAdapter < GreenApiAdapter
    CHANNEL = 'whatsapp'
  end
end
