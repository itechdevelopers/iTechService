class IphoneSalesImport < ApplicationRecord
  validates :delivery_id, :period_from, :period_to, :calculated_at, :methodology_version, presence: true
  validates :delivery_id, uniqueness: true
  validates :status, inclusion: {in: %w[successful failed]}
  scope :successful, -> { where(status: 'successful') }
  scope :newest_first, -> { order(calculated_at: :desc, id: :desc) }
end
