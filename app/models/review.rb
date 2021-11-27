class Review < ApplicationRecord
  belongs_to :client
  belongs_to :service_job
  belongs_to :user
end
