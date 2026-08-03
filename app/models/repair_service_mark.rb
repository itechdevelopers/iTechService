# frozen_string_literal: true

class RepairServiceMark < ApplicationRecord
  NOTIFICATION_CODE = 'notification'

  default_scope { order(:position, :id) }

  has_many :repair_services, dependent: :nullify

  validates :name, presence: true

  def self.notification
    find_by(code: NOTIFICATION_CODE)
  end
end
