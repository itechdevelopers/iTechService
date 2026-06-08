class FaultKind < ApplicationRecord
  PENALTIES_COUNT = 4

  scope :ordered, -> { order :name }
  scope :permanent, -> { where is_permanent: true }
  scope :expireable, -> { where is_permanent: false }
  scope :monthly, -> { expireable }
  scope :financial, -> { where financial: true }
  scope :exchangeable, -> { where exchangeable: true }

  has_many :faults, foreign_key: :kind_id, dependent: :delete_all

  mount_uploader :icon, IconUploader

  def penalties
    self[:penalties]&.split(',')&.map(&:to_i) || Array.new(PENALTIES_COUNT, nil)
  end

  def penalties=(new_value)
    super new_value.compact.map(&:to_s).join(',')
  end
end
