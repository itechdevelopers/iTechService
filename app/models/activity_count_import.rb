class ActivityCountImport < ApplicationRecord
  validates :metric, inclusion: {in: %w[receipts issued_repairs]}
  validates :delivery_id, :period_from, :period_to, :calculated_at, presence: true
end
