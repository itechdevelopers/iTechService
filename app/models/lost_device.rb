class LostDevice < ApplicationRecord
  belongs_to :service_job, optional: true
end
