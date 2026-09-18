# frozen_string_literal: true

# rubocop:disable Metrics

module KpiAudit
  # Caps correlated evidence families and applies explicit combination bonuses.
  class Scorecard
    LEVELS = { 0..24 => :low, 25..49 => :moderate, 50..74 => :high, 75..100 => :critical }.freeze
    Contribution = Struct.new(:code, :description, :raw_points, :effective_points, :family,
                              keyword_init: true) do
      def to_h
        members.to_h { |name| [name, public_send(name)] }
      end
    end
    Assessment = Struct.new(:score, :level, :contributions, keyword_init: true) do
      def to_h
        { score: score, level: level, contributions: contributions.map(&:to_h) }
      end
    end

    def initialize(configuration: Configuration.load)
      @configuration = configuration
    end

    def score(reasons)
      assess(reasons).score
    end

    def assess(reasons)
      contributions = capped_reason_contributions(reasons)
      combination_contributions(reasons).each do |item|
        remaining = 100 - contributions.sum(&:effective_points)
        item.effective_points = [item.raw_points, remaining].min.clamp(0, item.raw_points)
        contributions << item
      end
      total = contributions.sum(&:effective_points)
      Assessment.new(score: total, level: level(total), contributions: contributions.freeze)
    end

    def level(score)
      LEVELS.find { |range, _| range.cover?(score) }&.last || (score.to_f.negative? ? :low : :critical)
    end

    private

    def family_cap(family)
      @configuration.fetch(:family_caps).fetch(family.to_sym, 100)
    end

    def capped_reason_contributions(reasons)
      used = Hash.new(0)
      reasons.map do |reason|
        remaining = family_cap(reason.family) - used[reason.family]
        effective = [reason.points, remaining].min.clamp(0, reason.points)
        used[reason.family] += effective
        Contribution.new(code: reason.code, description: reason.text, raw_points: reason.points,
                         effective_points: effective, family: reason.family)
      end
    end

    def combination_contributions(reasons)
      codes = reasons.map(&:code)
      result = []
      if codes.include?(:end_of_period) && codes.include?(:no_monetary_result)
        result << combination(:end_period_without_result,
                              'Комбинация всплеска конца периода и отсутствия экономического результата.')
      end
      if codes.include?(:burst) && (codes & %i[repeated_client repeated_device]).any?
        result << combination(:burst_repeated_entity, 'Комбинация плотной серии и повторяющейся сущности.')
      end
      result
    end

    def combination(code, description)
      Contribution.new(code: code, description: description,
                       raw_points: @configuration.fetch(:combinations, code),
                       effective_points: 0, family: :combination)
    end
  end
end
# rubocop:enable Metrics
