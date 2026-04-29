class ElectronicQueueInactivityThreshold < ApplicationRecord
  belongs_to :electronic_queue

  validates :total_on_shift,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :max_inactive,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :total_on_shift,
            uniqueness: { scope: :electronic_queue_id }
  validate :max_inactive_less_than_total_on_shift

  private

  def max_inactive_less_than_total_on_shift
    return if max_inactive.blank? || total_on_shift.blank?
    return if max_inactive < total_on_shift

    errors.add(:max_inactive, :must_be_less_than_total_on_shift)
  end
end
