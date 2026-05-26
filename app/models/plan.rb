class Plan < ApplicationRecord
  METRICS = User::ACTIVITIES

  belongs_to :city

  validates :month,  presence: true
  validates :metric, presence: true, inclusion: { in: METRICS }
  validates :target, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :city_id, uniqueness: { scope: %i[month metric] }
  validate  :month_is_first_day_of_month

  before_validation :normalize_month

  scope :for_month,  ->(date)   { where(month: date.to_date.beginning_of_month) }
  scope :for_city,   ->(city)   { where(city_id: city) }
  scope :for_metric, ->(metric) { where(metric: metric) }

  def self.target_for(month:, city_id:, metric:)
    find_by(month: month.to_date.beginning_of_month, city_id: city_id, metric: metric)&.target
  end

  private

  def normalize_month
    return if month.blank?

    self.month = month.to_date.beginning_of_month
  end

  def month_is_first_day_of_month
    return if month.blank?

    errors.add(:month, :must_be_first_of_month) if month != month.beginning_of_month
  end
end
