# frozen_string_literal: true

module Bot
  module DeviceModelMatcher
    module_function

    def matches?(requested, actual)
      parse(requested) == parse(actual)
    end

    def parse(value)
      match = value.to_s.downcase.match(/\b(iphone|ipad|macbook|apple watch)\s*(\d+)?(?:\s+(pro\s+max|pro|max|plus|mini|air|ultra))?\b/)
      return value.to_s.downcase.strip unless match

      [match[1], match[2], match[3].to_s.split.join(' ')].compact.join(' ')
    end
  end
end
