# frozen_string_literal: true

module KpiAudit
  # JSON-ready presentation object: one card per reconstructed customer visit.
  class Episode
    ATTRIBUTES = %i[id summary employee visit_profile signals risk_score risk_level confidence
                    timeline economic_outcome video_summary related_records limitations].freeze

    attr_reader(*ATTRIBUTES)

    def initialize(**attributes)
      ATTRIBUTES.each { |name| instance_variable_set("@#{name}", attributes.fetch(name)) }
      freeze
    end

    def to_param
      id
    end

    def to_h
      ATTRIBUTES.to_h { |name| [name, public_send(name)] }
    end
  end
end
