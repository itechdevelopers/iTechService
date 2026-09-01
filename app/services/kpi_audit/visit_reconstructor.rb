# frozen_string_literal: true

# rubocop:disable Metrics

ActiveSupport::Dependencies.require_dependency 'kpi_audit/types'

module KpiAudit
  # Reconstructs visits from strong keys while treating client_id as weak evidence.
  class VisitReconstructor
    def initialize(events:, configuration: Configuration.load)
      @events = events.sort_by(&:occurred_at)
      @gap = configuration.fetch(:visit, :medium_gap_minutes).minutes
    end

    def call
      groups = strong_components
      attach_medium_evidence(groups)
      groups.each_with_index.map do |events, index|
        keys = events.flat_map(&:strong_keys).uniq
        Visit.new(id: index + 1, events: events.sort_by(&:occurred_at),
                  confidence: keys.any? ? :strong : :medium, evidence: keys)
      end
    end

    private

    def strong_components
      groups = []
      @events.each do |event|
        matches = groups.select { |group| group.any? { |member| strong_match?(member, event) } }
        if matches.empty?
          groups << [event]
        else
          merged = matches.flatten + [event]
          groups -= matches
          groups << merged.uniq
        end
      end
      groups
    end

    def strong_match?(left, right)
      shared = left.strong_keys & right.strong_keys
      return false if shared.empty?
      return true if shared.any? { |key| key.start_with?('ticket:', 'service_job:') }

      (left.occurred_at - right.occurred_at).abs <= @gap
    end

    # client_id is deliberately only supporting evidence. It may attach an event
    # to an already strongly confirmed visit, but never merges two visits.
    def attach_medium_evidence(groups)
      groups.select { |group| group.flat_map(&:strong_keys).any? }.each do |group|
        candidates = groups.select do |other|
          next false if other.equal?(group) || other.flat_map(&:strong_keys).any?

          medium_match?(group, other)
        end
        candidates.each do |candidate|
          group.concat(candidate)
          groups.delete(candidate)
        end
      end
    end

    def medium_match?(left, right)
      left.any? do |a|
        right.any? do |b|
          a.client_id.present? && a.client_id == b.client_id &&
            a.employee_id == b.employee_id && (a.occurred_at - b.occurred_at).abs <= @gap
        end
      end
    end
  end
end
# rubocop:enable Metrics
