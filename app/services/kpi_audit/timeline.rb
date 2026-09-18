# frozen_string_literal: true

module KpiAudit
  # One known event on an investigation timeline.
  class TimelineEntry
    ATTRIBUTES = %i[type occurred_at time_status title description source_type source_id url confidence].freeze
    attr_reader(*ATTRIBUTES)

    def initialize(**attributes)
      ATTRIBUTES.each { |name| instance_variable_set("@#{name}", attributes[name]) }
      freeze
    end

    def to_h
      ATTRIBUTES.each_with_object({}) { |name, result| result[name] = public_send(name) }
    end
  end

  # Chronologically ordered immutable collection of known facts.
  class Timeline
    attr_reader :entries

    def initialize(entries)
      @entries = entries.sort_by do |entry|
        [entry.occurred_at ? 0 : 1, entry.occurred_at || Time.at(0), entry.type.to_s, entry.source_id.to_i]
      end.freeze
      freeze
    end

    def to_h
      entries.map(&:to_h)
    end
  end
end
