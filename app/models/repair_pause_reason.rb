class RepairPauseReason < ApplicationRecord
  URGENT_REPAIR = 'urgent_repair'.freeze
  GLUING = 'gluing'.freeze
  TESTING = 'testing'.freeze
  WAITING_APPROVAL = 'waiting_approval'.freeze

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

  def testing?
    code == TESTING
  end

  def waiting_approval?
    code == WAITING_APPROVAL
  end

  # Тест и согласование заканчиваются своим событием — возвратом с теста или
  # ответом клиента — и держат открытую запись; по сроку им только напоминаем.
  def auto_resume?
    !testing? && !waiting_approval?
  end
end
