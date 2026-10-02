# frozen_string_literal: true

class RepairServiceMark < ApplicationRecord
  NOTIFICATION_CODE = 'notification'

  default_scope { order(:position, :id) }

  # Отметку, которая стоит у видов ремонта, не удаляем: она молча слетела бы со всех
  # них и пропала с сайта, который получает её через Repair API (RepairServiceEntity#mark).
  has_many :repair_services, dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, numericality: { only_integer: true }, allow_nil: true

  def self.notification
    find_by(code: NOTIFICATION_CODE)
  end
end
