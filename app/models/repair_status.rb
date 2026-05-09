class RepairStatus < ApplicationRecord
  WAITING     = 'waiting'.freeze
  IN_PROGRESS = 'in_progress'.freeze
  PAUSED      = 'paused'.freeze
  COMPLETED   = 'completed'.freeze

  has_many :service_jobs, dependent: :restrict_with_error
  has_many :repair_status_changes_from, class_name: 'RepairStatusChange', foreign_key: :from_status_id, dependent: :restrict_with_error
  has_many :repair_status_changes_to,   class_name: 'RepairStatusChange', foreign_key: :to_status_id,   dependent: :restrict_with_error

  validates :code, :name, :color, presence: true
  validates :code, uniqueness: true

  scope :active,  -> { where(archived: false) }
  scope :ordered, -> { order(:position) }

  def self.by_code(code)
    find_by!(code: code)
  end

  def waiting?     ; code == WAITING     end
  def in_progress? ; code == IN_PROGRESS end
  def paused?      ; code == PAUSED      end
  def completed?   ; code == COMPLETED   end
end
