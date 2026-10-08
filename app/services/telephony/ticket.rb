# frozen_string_literal: true
require 'openssl'
require 'base64'
require 'securerandom'
module Telephony
  class Ticket
    TTL = 60
    def self.issue(user, now: Time.now.to_i)
      payload = { v: 1, aud: 'ais-telephony-gateway', user_id: user.id,
                  extension: user.telephony_extension, iat: now, exp: now + TTL,
                  jti: SecureRandom.hex(16) }
      encoded = Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
      digest = OpenSSL::HMAC.hexdigest('SHA256', Configuration.secret, encoded)
      "#{encoded}.#{digest}"
    end
  end
end
