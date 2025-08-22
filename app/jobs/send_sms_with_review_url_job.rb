class SendMessageWithReviewUrlJob < ApplicationJob
  include Rails.application.routes.url_helpers
  queue_as :default

  def perform(review_id)
    review = Review.find review_id
    service_job = review.service_job
    message = Setting.request_review_text(service_job.department)
    review_url = "#{root_url}review/#{review.token}"
    
    # Send via WhatsApp
    result1 = SendWhatsapp.call(number: review.phone, message: message)
    
    if result1.success?
      sleep(1)
      result2 = SendWhatsapp.call(number: review.phone, message: review_url)
      
      if result2.success?
        review.update(sent_at: DateTime.now, status: :sent)
      else
        review.update(status: :error)
        Rails.logger.error("[SendMessageWithReviewUrlJob] URL send failed for review #{review_id}: #{result2.result}")
      end
    else
      review.update(status: :error)
      Rails.logger.error("[SendMessageWithReviewUrlJob] Message send failed for review #{review_id}: #{result1.result}")
    end
    
    review.status
  end
end