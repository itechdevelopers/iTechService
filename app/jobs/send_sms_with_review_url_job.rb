class SendSmsWithReviewUrlJob  < ApplicationJob
  include Rails.application.routes.url_helpers
  queue_as :default

  def perform(review_id)
    review = Review.find review_id
    service_job = review.service_job
    message = Setting.request_review_text(service_job.department)
    review_url = "#{root_url}review/#{review.token}"
    s1 = SendSMS.call(number: review.phone, message: message).success?
    s2 = SendSMS.call(number: review.phone, message: review_url).success?
    if s1 && s2
      review.update(sent_at: DateTime.now, status: :sent)
    else
      review.update(status: :error)
    end
  end
end