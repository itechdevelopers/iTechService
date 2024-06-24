class ClientReviewsReport < BaseReport

  def call
    @result = { name: "Отзывы клиентов", data: client_reviews }
  end

  private

  def client_reviews
    reviews = Review.where(status: "reviewed")
                    .where.not(client_id: nil)
                    .where.not(user_id: nil)
                    .where.not(service_job_id: nil)
                    .joins(:service_job)
                    .where(service_jobs: { department_id: department_ids })
                    .where(reviewed_at: period)

    reviews.map do |review|
      {
        id: review.id,
        job: review.service_job.ticket_number,
        user: review.user.short_name,
        date_time: review.reviewed_at.strftime("%d.%m.%Y %H:%M"),
        review: review.value,
        comment: review.content,
        linkable: ["service_job", review.service_job.id]
      }
    end
  end
end