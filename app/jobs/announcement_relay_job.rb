class AnnouncementRelayJob < ApplicationJob
  queue_as :announcement

  def perform(announcement_id)
    #TODO implement via cable
    # PrivatePub.publish_to '/announcements', "$.getScript('/announcements/#{announcement_id}');"
  end
end