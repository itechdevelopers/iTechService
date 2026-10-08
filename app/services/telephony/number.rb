# frozen_string_literal: true
module Telephony
  module Number
    module_function
    # Only known routing prefixes are removed. Do not turn an arbitrary label
    # containing digits into a customer's phone number.
    def normalize(value)
      raw = value.to_s.strip.sub(/\A(?:влд|сакх|vld|sakh)[\s:;_\-]*/i, '')
      return nil unless raw.match?(/\A\+?[\d\s()\-]+\z/)
      digits = raw.gsub(/\D/, '')
      digits = '7' + digits[1..-1] if digits.length == 11 && digits.start_with?('8')
      digits.match?(/\A7\d{10}\z/) ? digits : nil
    end

    def dialable(value)
      raw = value.to_s.strip
      return raw if raw.match?(/\A\d{3,4}\z/)
      normalize(raw)
    end
  end
end
