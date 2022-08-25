class Review < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :service_job, optional: true
  belongs_to :user, optional: true

  def sent?
    status == 'sent'
  end

  def viewed!
    update! status: 'viewed'
  end
end
