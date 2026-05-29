class RepairPauseReason < ApplicationRecord
  URGENT_REPAIR = 'urgent_repair'.freeze
  GLUING = 'gluing'.freeze

  has_many :repair_status_changes, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true

  scope :active, -> { where(archived: false) }
  scope :ordered, -> { order(:position) }

  def urgent_repair?
    code == URGENT_REPAIR
  end

  def gluing?
    code == GLUING
  end
end
