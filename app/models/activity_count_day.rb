class ActivityCountDay < ApplicationRecord
  belongs_to :activity_count_import
  validates :metric, inclusion: {in: %w[receipts issued_repairs]}
  validates :date, presence: true
  validates :quantity, numericality: {only_integer: true, greater_than_or_equal_to: 0}
end
