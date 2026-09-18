# frozen_string_literal: true

module KpiAudit
  # Immutable, serializable video context. It never retains AR or NVR secrets.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  class VideoSummary
    ATTRIBUTES = %i[available playback_available status explanation queue_name queue_key ticket_id ticket_number
                    window_number camera_name camera_key channel fallback_cameras range_start range_end
                    confidence_score confidence_reasons primary_link alternative_links diagnostics].freeze

    attr_reader(*ATTRIBUTES)

    def initialize(**attributes)
      ATTRIBUTES.each { |name| instance_variable_set("@#{name}", attributes[name]) }
      @available = @available == true
      @confidence_reasons = Array(@confidence_reasons).map(&:to_s).freeze
      @fallback_cameras = Array(@fallback_cameras).map(&:to_s).freeze
      @alternative_links = Array(@alternative_links).freeze
      @diagnostics = (attributes[:diagnostics] || {}).deep_dup.freeze
      freeze
    end

    def available?
      available
    end

    def to_h(diagnostics: false)
      result = {
        available: available, status: status, explanation: explanation,
        queue_name: queue_name, queue_key: queue_key, ticket_id: ticket_id,
        ticket_number: ticket_number, window_number: window_number,
        camera_name: camera_name, camera_key: camera_key, channel: channel,
        fallback_cameras: fallback_cameras, range_start: range_start, range_end: range_end,
        confidence_score: confidence_score, confidence_reasons: confidence_reasons,
        primary_link: primary_link&.to_h,
        alternative_links: alternative_links.map(&:to_h)
      }
      result[:diagnostics] = self.diagnostics if diagnostics
      result
    end

    def inspect
      "#<#{self.class.name} status=#{status.inspect} available=#{available.inspect} " \
        "ticket_id=#{ticket_id.inspect} camera=#{camera_key.inspect}>"
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
