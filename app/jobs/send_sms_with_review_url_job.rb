class SendMessageWithReviewUrlJob < ApplicationJob
  include Rails.application.routes.url_helpers
  queue_as :default

  def perform(review_id)
    review = Review.find review_id
    service_job = review.service_job
    message_text = Setting.request_review_text(service_job.department)
    review_url = "#{root_url}review/#{review.token}"

    # Merge message text with review URL for a single WhatsApp message
    merged_message = "#{message_text}: #{review_url}"

    # Create SMS notification record for audit trail
    sms_notification = Service::SMSNotification.create!(
      sender: review.user,
      service_job: service_job,
      phone_number: review.phone,
      message: merged_message,
      sent_at: DateTime.current,
      message_type: 'whatsapp'
    )

    # Send via WhatsApp
    result = SendWhatsapp.call(number: review.phone, message: merged_message)

    if result.success?
      review.update(sent_at: DateTime.now, status: :sent)
      # Update SMS notification with message_id from WhatsApp
      sms_notification.update(message_id: result.message_id) if result.message_id
    else
      review.update(status: :error)
      Rails.logger.error("[SendMessageWithReviewUrlJob] Message send failed for review #{review_id}: #{result.result}")
    end

    review.status
  end
end