module ServiceJobs
  class MakeReview
    prepend BaseInteractor

    option :user
    option :service_job

    def call
      return unless user.able_to?(:request_review)
      time_out = Setting.request_review_time_out(service_job.department) * 60
      review = Review.create(
        service_job: service_job,
        user: current_user,
        client: service_job.client,
        phone: service_job.client.full_phone_number,
        token: SecureRandom.urlsafe_base64,
        status: :draft
      )
      SendSmsWithReviewUrlJob.set(wait: time_out).perform_later(review.id)
    rescue StandardError => e
      Rails.logger.debug(e.message)
    end
  end
end