module Service
  class SMSNotification < ApplicationRecord
    self.table_name = 'service_sms_notifications'

    MESSAGE_TYPES = %w[sms whatsapp].freeze

    belongs_to :sender, class_name: 'User', optional: true
    validates_presence_of :phone_number, :message
    validates :message_type, inclusion: { in: MESSAGE_TYPES }
  end
end
