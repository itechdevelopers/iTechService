# frozen_string_literal: true
require 'uri'
module Telephony
  module WorkspacePath
    # Same pattern is rendered into the workspace for client-side validation.
    PATTERN = '^(?!//)(?!/telephony(?:[/.?#]|$))(?!.*/(?:\.|%2[eE]){1,2}(?:/|[?#]|$))(?!.*[\\\\\x00-\x1f\x7f])/.*$'.freeze
    MATCHER = Regexp.new(PATTERN.sub(/\A\^/, "\\A").sub(/\$\z/, "\\z"))
    def self.valid?(path)
      return false unless path.is_a?(String) && MATCHER.match?(path)
      pathname = path.split(/[?#]/, 2).first
      return false if pathname.match?(/%(?![0-9a-fA-F]{2})/)
      MATCHER.match?(URI::DEFAULT_PARSER.unescape(pathname))
    rescue ArgumentError
      false
    end
  end
end
