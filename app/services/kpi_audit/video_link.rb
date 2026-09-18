# frozen_string_literal: true

module KpiAudit
  # Credential-free link displayed to an investigation reviewer.
  # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
  class VideoLink
    USER_LABEL = 'Смотреть видео события'
    TYPES = %i[hikvision_web hikvision_rtsp ais_video download].freeze

    ATTRIBUTES = %i[type label url available requires_local_network requires_authentication
                    camera_name channel start_time end_time explanation].freeze

    attr_reader(*ATTRIBUTES)

    def initialize(type:, url:, available: true, label: USER_LABEL, requires_local_network: false,
                   requires_authentication: true, camera_name: nil, channel: nil,
                   start_time: nil, end_time: nil, explanation: nil)
      raise ArgumentError, "unknown video link type #{type.inspect}" unless TYPES.include?(type.to_sym)

      @type = type.to_sym
      @label = label
      @url = url
      @available = available == true && url.present?
      @requires_local_network = requires_local_network == true
      @requires_authentication = requires_authentication == true
      @camera_name = camera_name
      @channel = channel
      @start_time = start_time
      @end_time = end_time
      @explanation = explanation
      freeze
    end

    def available?
      available
    end

    def to_h(diagnostics: false)
      result = { label: label, url: url, available: available }
      if diagnostics
        result.merge!(type: type, requires_local_network: requires_local_network,
                      requires_authentication: requires_authentication, camera_name: camera_name,
                      channel: channel, start_time: start_time, end_time: end_time,
                      explanation: explanation)
      end
      result
    end

    def inspect
      "#<#{self.class.name} type=#{type.inspect} available=#{available.inspect} camera=#{camera_name.inspect}>"
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists
end
