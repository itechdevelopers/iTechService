# frozen_string_literal: true

module ClientMessenger
  # MAX по номеру телефона, через GREEN-API.
  class MaxPhoneAdapter < GreenApiAdapter
    CHANNEL = 'max_phone'
  end
end
