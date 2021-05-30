class SendSmsWithReviewUrlJob  < ActiveJob::Base
  include Rails.application.routes.url_helpers
  queue_as :default

  def perform(review_id)
    review = Review.find review_id
    service_job = review.service_job
    message = Setting.request_review_text(service_job.department)
    review_url = "#{root_url}review/#{review.token}"
    if SendSMS.(number: review.phone, message: review_url).success? &&
      SendSMS.(number: review.phone, message: message).success?
      review.update(sent_at: DateTime.now)
    end
  end
end