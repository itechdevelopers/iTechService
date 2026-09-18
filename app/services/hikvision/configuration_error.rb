# frozen_string_literal: true

module Hikvision
  # Lightweight namespace for configuration errors without loading credentials.
  class Configuration
    class Error < StandardError; end unless const_defined?(:Error, false)
  end
end
