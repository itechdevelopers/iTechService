class BackfillServiceJobIdToSmsNotifications < ActiveRecord::Migration[5.1]
  def up
    # Backfill service_job_id for SMS notifications created in the last 5 days
    five_days_ago = 5.days.ago
    
    Service::SMSNotification.where(sent_at: five_days_ago.., service_job_id: nil).find_each do |sms_notification|
      # Extract ticket number from message (first number found in the message)
      ticket_number_match = sms_notification.message.match(/\d+/)
      
      if ticket_number_match
        ticket_number = ticket_number_match[0]
        
        # Find service job by ticket number
        service_job = ServiceJob.find_by(ticket_number: ticket_number)
        
        if service_job
          sms_notification.update_column(:service_job_id, service_job.id)
          Rails.logger.info "Linked SMS notification ID #{sms_notification.id} to service job ID #{service_job.id} (ticket #{ticket_number})"
        else
          Rails.logger.warn "Service job with ticket number #{ticket_number} not found for SMS notification ID #{sms_notification.id}"
        end
      else
        Rails.logger.warn "No ticket number found in message for SMS notification ID #{sms_notification.id}"
      end
    end
  end
  
  def down
    # Remove backfilled service_job_ids (optional, can be left as no-op)
    five_days_ago = 5.days.ago
    Service::SMSNotification.where(sent_at: five_days_ago..).update_all(service_job_id: nil)
  end
end
