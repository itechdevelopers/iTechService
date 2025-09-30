class BackfillRemainingReviewSmsNotifications < ActiveRecord::Migration[5.1]
  def up
    # Backfill SMS notifications for reviews sent in the last 7 days
    # No duplicate checking - create notifications for ALL reviews
    seven_days_ago = 7.days.ago

    Review.where(sent_at: seven_days_ago.., status: 'sent').find_each do |review|
      begin
        # Construct the review message exactly as SendMessageWithReviewUrlJob does
        service_job = review.service_job
        message_text = Setting.request_review_text(service_job&.department)

        # Construct review URL with production root URL
        review_url = "https://ise.itech.pw/review/#{review.token}"

        # Merge message text with review URL (same format as the job)
        merged_message = "#{message_text}: #{review_url}"

        # Create SMS notification record
        Service::SMSNotification.create!(
          sender_id: review.user_id,
          service_job_id: review.service_job_id,
          phone_number: review.phone,
          message: merged_message,
          sent_at: review.sent_at,
          message_type: 'whatsapp',
          created_at: review.sent_at,
          updated_at: review.sent_at
        )

        Rails.logger.info "Created SMS notification for review ID #{review.id} (service job #{review.service_job_id})"
      rescue => e
        Rails.logger.warn "Failed to create SMS notification for review ID #{review.id}: #{e.message}"
      end
    end

    Rails.logger.info "Backfill complete. Processed reviews from the last 7 days."
  end

  def down
    # No-op: we don't delete SMS notifications on rollback
  end
end
