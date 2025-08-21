module Service
  class SMSNotification::Build < ATransaction
    map :build

    private

    def build(service_job_id:, **)
      service_job = ServiceJob.find(service_job_id)
      template = Setting.sms_notification_template(service_job.department)
      
      # Use default message if template is not configured
      template = I18n.t('service.sms_notification.default_message') if template.blank?
      
      message = template
                  .gsub('{brand}', service_job.department&.brand_name || '')
                  .gsub('{ticket_number}', service_job.ticket_number || '')
                  .gsub('{contact_phone}', Setting.contact_phone_short(service_job.department) || '')
                  
      SMSNotification.new message: message
    end
  end
end
