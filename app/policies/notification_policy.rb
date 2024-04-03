class NotificationPolicy < BasePolicy
  def user_notifications?
    read?
  end

  def close?
    view_notifications?
  end

  def view_notifications?
    owner? || superadmin?
  end

  private

  def owner?
    user.id == record.user_id
  end
end