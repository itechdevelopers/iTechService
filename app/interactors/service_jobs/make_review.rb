module ServiceJobs
  class MakeReview
    prepend BaseInteractor

    option :user
    option :service_job

    def call
      Rollbar.debug(log_info)
      return unless user.able_to?(:request_review)
      time_out = Setting.request_review_time_out(service_job.department) * 60
      Rollbar.debug({token: token, time_out: time_out}.to_s)
      review = Review.create(
        service_job: service_job,
        user: current_user,
        client: service_job.client,
        phone: service_job.client.full_phone_number,
        token: token,
        status: :draft
      )
      Rollbar.debug({review: review}.to_s)
      SendSmsWithReviewUrlJob.set(wait: time_out).perform_later(review.id)
    rescue StandardError => e
      Rails.logger.debug(e.message)
      Rollbar.error(e)
    end

    private

    def token
      @token ||= SecureRandom.urlsafe_base64
    end

    def log_info
      {
        message: 'ServiceJobs::MakeReview.call start',
        token: token,
        user: user.to_json,
        service_job: service_job.as_json
      }.to_s
    end
  end
end