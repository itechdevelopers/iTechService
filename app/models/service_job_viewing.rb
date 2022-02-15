class ServiceJobViewing < ApplicationRecord
  scope :new_first, -> { order time: :desc }

  belongs_to :service_job, optional: true
  belongs_to :user, optional: true

  # attr_accessible :service_job, :user, :time, :ip

  delegate :presentation, to: :user, prefix: true
end
