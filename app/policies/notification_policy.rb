class NotificationPolicy < BasePolicy
  def user_notifications?
    user == record.user
  end
end