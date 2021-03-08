class ServiceJobViewing < ActiveRecord::Base
  scope :new_first, -> { order time: :desc }

  belongs_to :service_job
  belongs_to :user

  # attr_accessible :service_job, :user, :time, :ip

  delegate :presentation, to: :user, prefix: true
end
