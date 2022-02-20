class ServiceJobViewing < ApplicationRecord
  scope :new_first, -> { order time: :desc }

  belongs_to :service_job, optional: true
  belongs_to :user, optional: true

  delegate :presentation, to: :user, prefix: true
end
