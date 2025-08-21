module ServiceJobs
  class MakeReview
    prepend BaseInteractor

    option :user
    option :service_job

    def call
      unless user_able_to_request_review
        return
      end

      time_out = Setting.request_review_time_out(service_job.department) * 60
      review = Review.create(
        service_job: service_job,
        user: user,
        client: service_job.client,
        phone: service_job.client.full_phone_number,
        token: token,
        status: :draft
      )
      SendMessageWithReviewUrlJob.set(wait: time_out).perform_later(review.id)
    rescue StandardError => e
      Rails.logger.debug(e.message)
    end

    private

    def user_able_to_request_review
      @user_able_to_request_review ||= user.able_to?(:request_review)
    end

    def token
      @token ||= SecureRandom.urlsafe_base64
    end

    def log_info
      {
        message: 'ServiceJobs::MakeReview.call start',
        token: token,
        user_able_to_request_review: user_able_to_request_review,
        user: user.to_json,
        service_job: service_job.as_json
      }.to_s
    end
  end
end