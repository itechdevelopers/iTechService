# frozen_string_literal: true

require 'open3'
require_relative 'configuration_error'

module Hikvision
  # Imports only the Hikvision settings from the trusted login-shell profile.
  class RuntimeEnvironment
    KEYS = %w[HIKVISION_HOST HIKVISION_USER HIKVISION_PASSWORD HIKVISION_RTSP_PORT].freeze
    SHELL_COMMAND = <<~'SH'
      . /etc/profile >/dev/null 2>&1
      printf '%s\0%s\0' HIKVISION_HOST "$HIKVISION_HOST"
      printf '%s\0%s\0' HIKVISION_USER "$HIKVISION_USER"
      printf '%s\0%s\0' HIKVISION_PASSWORD "$HIKVISION_PASSWORD"
      printf '%s\0%s\0' HIKVISION_RTSP_PORT "$HIKVISION_RTSP_PORT"
    SH

    def initialize(env: ENV, runner: nil)
      @env = env
      @runner = runner || ->(*arguments) { Open3.capture3(*arguments) }
    end

    # The method intentionally keeps the import flow together and bounded to KEYS.
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    def import!
      missing = KEYS.reject { |key| present?(@env[key]) }
      return @env if missing.empty?

      stdout, _stderr, status = @runner.call('/bin/bash', '-lc', SHELL_COMMAND)
      raise Configuration::Error, 'Unable to load Hikvision runtime environment' unless status.success?

      values = parse(stdout)
      missing.each do |key|
        value = values[key]
        @env[key] = value if present?(value)
      end

      unresolved = KEYS.reject { |key| present?(@env[key]) }
      return @env if unresolved.empty?

      raise Configuration::Error, "Missing required Hikvision ENV #{unresolved.join(', ')}"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

    private

    def present?(value)
      value.respond_to?(:empty?) ? !value.empty? : !value.nil?
    end

    def parse(output)
      fields = output.to_s.split("\0", -1)
      fields.each_slice(2).each_with_object({}) do |(key, value), result|
        result[key] = value if KEYS.include?(key)
      end
    end
  end
end
