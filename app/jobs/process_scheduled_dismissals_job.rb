class ProcessScheduledDismissalsJob < ApplicationJob
  queue_as :default

  def perform
    users = User.where(is_fired: [false, nil])
                .where.not(dismissed_date: nil)
                .where('dismissed_date <= ?', Date.current)

    users.find_each do |user|
      user.update!(is_fired: true)
      Rails.logger.info("[ProcessScheduledDismissals] Fired user ##{user.id} (#{user.short_name}), dismissed_date: #{user.dismissed_date}")
    end
  end
end
