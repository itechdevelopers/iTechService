# frozen_string_literal: true
require 'uri'

module Mcp
  module Configuration
    SCOPES = %w[ais:read ais:write ais:revenue].freeze
    def self.enabled?
      ENV['AIS_MCP_ENABLED'] == '1'
    end

    def self.origin
      value = ENV.fetch('AIS_MCP_PUBLIC_ORIGIN')
      uri = URI.parse(value)
      raise ArgumentError, 'HTTPS origin required' unless uri.scheme == 'https' && uri.host && uri.path.to_s.empty? && !uri.query && !uri.fragment && !uri.userinfo
      value
    end

    def self.resource
      "#{origin}/mcp"
    end

    def self.client_id
      ENV.fetch('AIS_MCP_OAUTH_CLIENT_ID')
    end

    def self.redirect_uris
      ENV.fetch('AIS_MCP_OAUTH_REDIRECT_URIS').split(',').map(&:strip).tap do |values|
        raise ArgumentError, 'HTTPS callback required' if values.empty? || values.any? { |value| uri = URI.parse(value); uri.scheme != 'https' || !uri.host || uri.fragment || uri.userinfo || uri.host.include?('*') }
      end
    end
  end
end
