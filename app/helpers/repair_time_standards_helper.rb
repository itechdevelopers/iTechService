module RepairTimeStandardsHelper
  # Пороги «достоверности» медианы по числу чистых образцов (согласовано 29.07.2026):
  # чем больше образцов, тем «чётче» время. <10 — без заливки.
  CONFIDENCE_TIERS = [[100, 'gold'], [50, 'purple'], [30, 'red'], [20, 'orange'], [10, 'yellow']].freeze

  # BEM-класс заливки ячейки количества по числу образцов (или nil, если < 10).
  def time_standard_confidence_class(sample_count)
    tier = CONFIDENCE_TIERS.find { |min, _| sample_count.to_i >= min }
    "repair-time-standards__count--#{tier.last}" if tier
  end
end
