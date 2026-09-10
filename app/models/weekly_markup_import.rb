class WeeklyMarkupImport < ApplicationRecord
  STATUSES = %w[successful failed].freeze

  validates :delivery_id, :period_from, :period_to, :calculated_at, :methodology_version, :status, presence: true
  validates :delivery_id, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validate :period_order

  scope :successful, -> { where(status: 'successful') }
  scope :failed, -> { where(status: 'failed') }
  scope :newest_first, -> { order(calculated_at: :desc, created_at: :desc) }
  scope :overlapping, ->(from, to) { where('period_from <= ? AND period_to >= ?', to, from) }

  private

  def period_order
    errors.add(:period_to, 'меньше начала периода') if period_from && period_to && period_to < period_from
  end
end
