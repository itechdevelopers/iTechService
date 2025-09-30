class BackfillReviewSmsNotifications < ActiveRecord::Migration[5.1]
  def up
    # Backfill SMS notifications for reviews sent in the last 7 days
    seven_days_ago = 7.days.ago

    Review.where(sent_at: seven_days_ago.., status: 'sent').find_each do |review|
      # Skip if SMS notification already exists for this review
      # Check by combination of service_job_id, phone, and sent_at to avoid duplicates
      next if Service::SMSNotification.exists?(
        service_job_id: review.service_job_id,
        phone_number: review.phone,
        sent_at: (review.sent_at - 1.minute)..(review.sent_at + 1.minute)
      )

      begin
        # Construct the review message
        message = construct_review_message(review)

        # Create SMS notification record
        Service::SMSNotification.create!(
          sender_id: review.user_id,
          service_job_id: review.service_job_id,
          phone_number: review.phone,
          message: message,
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
    # Remove backfilled SMS notifications (optional)
    # We identify them by matching with reviews from the last 7 days
    seven_days_ago = 7.days.ago

    Review.where(sent_at: seven_days_ago.., status: 'sent').find_each do |review|
      Service::SMSNotification
        .where(
          service_job_id: review.service_job_id,
          phone_number: review.phone,
          sent_at: (review.sent_at - 1.minute)..(review.sent_at + 1.minute)
        )
        .destroy_all
    end
  end

  private

  def construct_review_message(review)
    # Get the department from the service job
    department = review.service_job&.department

    # Get the review request text template
    message_text = if department
                     Setting.request_review_text(department)
                   else
                     Setting.request_review_text(nil)
                   end

    # Fallback to default message if template is not configured
    message_text = "Please rate our service" if message_text.blank?

    # Construct the review URL (approximating the root_url)
    # Note: In migration context, we don't have access to URL helpers
    # So we'll use a reasonable default or extract from existing data
    review_url = construct_review_url(review)

    # Combine message and URL
    "#{message_text}: #{review_url}"
  end

  def construct_review_url(review)
    # Try to extract domain from existing SMS notifications if available
    existing_notification = Service::SMSNotification
                           .where.not(message: nil)
                           .where("message LIKE ?", "%/review/%")
                           .first

    if existing_notification
      # Extract base URL from existing message
      match = existing_notification.message.match(%r{(https?://[^/]+)/review/})
      base_url = match[1] if match
    end

    # Fallback to reasonable default if we couldn't extract
    base_url ||= "https://itechservice.kz"

    "#{base_url}/review/#{review.token}"
  end
end