class TelephonySyncState < ApplicationRecord
  validates :source, inclusion: { in: %w[ami cdr] }, uniqueness: true
  validates :observed_at, presence: true
end
