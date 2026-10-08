# frozen_string_literal: true
module Telephony
  module Configuration
    module_function
    def enabled?
      ENV['TELEPHONY_ENABLED'] == 'true' && ENV['TELEPHONY_SHARED_SECRET'].to_s.bytesize >= 32 && !ENV['TELEPHONY_SHARED_SECRET'].start_with?('REPLACE')
    end
    def gateway_origin
      ENV.fetch('TELEPHONY_GATEWAY_ORIGIN', 'https://localhost:18444')
    end
    def ais_origin
      ENV.fetch('TELEPHONY_AIS_ORIGIN', 'https://ise.itech.pw')
    end
    def secret
      ENV.fetch('TELEPHONY_SHARED_SECRET')
    end
  end
end
