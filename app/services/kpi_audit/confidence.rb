# frozen_string_literal: true

module KpiAudit
  module Confidence
    Contribution = Struct.new(:code, :description, :raw_points, :effective_points, :family,
                              keyword_init: true) do
      def to_h
        members.to_h { |name| [name, public_send(name)] }
      end
    end

    # Explainable confidence that facts belong to one real visit.
    # rubocop:disable Metrics/MethodLength
    class Assessment
      attr_reader :score, :level, :contributions, :limitations

      def initialize(score:, contributions:, limitations:)
        @score = [[score.to_i, 0].max, 100].min
        @level = if @score >= 70
                   :high
                 elsif @score >= 40
                   :moderate
                 else
                   :low
                 end
        @contributions = contributions.freeze
        @limitations = limitations.freeze
        freeze
      end

      def to_h
        { score: score, level: level, contributions: contributions.map(&:to_h), limitations: limitations }
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
