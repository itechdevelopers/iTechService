module Service
  class SMSNotification < ApplicationRecord
    self.table_name = 'service_sms_notifications'

    MESSAGE_TYPES = %w[sms whatsapp].freeze
    WHATSAPP_STATUSES = %w[sent delivered read failed noAccount notInGroup].freeze

    belongs_to :sender, class_name: 'User', optional: true
    belongs_to :service_job, optional: true

    validates_presence_of :phone_number, :message
    validates :message_type, inclusion: { in: MESSAGE_TYPES }
    validates :whatsapp_status, inclusion: { in: WHATSAPP_STATUSES }, allow_blank: true

    # Scopes for filtering by status
    scope :delivered, -> { where(whatsapp_status: 'delivered') }
    scope :read, -> { where(whatsapp_status: 'read') }
    scope :failed, -> { where(whatsapp_status: ['failed', 'noAccount', 'notInGroup']) }
    scope :pending, -> { where(whatsapp_status: [nil, 'sent']) }

    # Status check helpers
    def delivered?
      whatsapp_status == 'delivered'
    end

    def read?
      whatsapp_status == 'read'
    end

    def failed?
      %w[failed noAccount notInGroup].include?(whatsapp_status)
    end

    def pending?
      whatsapp_status.nil? || whatsapp_status == 'sent'
    end

    # Status display helpers
    def status_icon
      case whatsapp_status
      when 'sent' then '✓'
      when 'delivered' then '✓✓'
      when 'read' then '✓✓' # will be styled blue in view
      when 'failed', 'noAccount', 'notInGroup' then '✗'
      else '◯'
      end
    end

    def status_text
      return 'pending' if whatsapp_status.blank?
      whatsapp_status
    end
  end
end
