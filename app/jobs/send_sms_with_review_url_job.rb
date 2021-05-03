class SendSmsWithReviewUrlJob  < ActiveJob::Base
  include Rails.application.routes.url_helpers
  queue_as :default

  def perform(review_id)
    review = Review.find review_id
    service_job = review.service_job
    message = Setting.request_review_text(service_job.department)
    message = "#{message} #{root_url}review/#{review.token}"
    send_sms = SendSMS.(number: review.phone, message: message)
    review.update(sent_at: DateTime.now) if send_sms.success?
  end
end