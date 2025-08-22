module Service
  class SMSNotification::Create < ATransaction
    map :prepare
    step :create
    step :dispatch

    private

    def prepare(service_job_id:, **params)
      service_job = ServiceJob.find(service_job_id)
      phone_number = get_phone_number(service_job)
      
      SMSNotification.new params[:service_sms_notification].merge(
        phone_number: phone_number,
        sent_at: DateTime.current,
        sender: params[:current_user],
        message_type: 'whatsapp'
      )
    end

    def get_phone_number(service_job)
      phone_number = service_job.contact_phone
      phone_number = service_job.client.full_phone_number if phone_number.blank? || phone_number == '-'
      phone_number
    end

    def create(sms_notification)
      if sms_notification.save
        Success sms_notification
      else
        Failure sms_notification
      end
    end

    def dispatch(sms_notification)
      result = SendWhatsapp.call(number: sms_notification.phone_number, message: sms_notification.message)

      if result.success?
        sms_notification.update(message_id: result.message_id) if result.message_id
        Success sms_notification
      else
        Failure result.result
      end
    end
  end
end
