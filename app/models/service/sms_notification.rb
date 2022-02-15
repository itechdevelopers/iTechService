module Service
  class SMSNotification < ApplicationRecord
    self.table_name = 'service_sms_notifications'

    belongs_to :sender, class_name: 'User', optional: true
    validates_presence_of :phone_number, :message
  end
end
