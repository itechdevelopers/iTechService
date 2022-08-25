class MarkReviewViewedJob < ApplicationJob
  queue_as :default

  def perform(id)
    review = Review.find(id)
    review.viewed! if review.sent?
  end
end
