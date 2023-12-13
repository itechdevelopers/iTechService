class BadReviewAnnouncementsJob < ApplicationJob
  queue_as :default

  def perform
    Announcement.active_bad_reviews.find_each do |announcement|
      announcement.update_column(:active, false) if announcement.created_at > 1.week.ago
    end
  end
end