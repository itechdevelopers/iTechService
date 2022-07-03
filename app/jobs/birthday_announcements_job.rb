class BirthdayAnnouncementsJob < ApplicationJob
  queue_as :default

  def perform
    Announcement.active_birthdays.find_each do |announcement|
      announcement.update_column(:active, false) unless announcement.user.upcoming_birthday?
    end

    User.active.find_each do |user|
      announcement = user.announcements.create_with(active: false).find_or_create_by(kind: 'birthday')
      announcement.update_column(:active, user.upcoming_birthday?)
    end
  end
end