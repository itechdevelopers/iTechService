class NotificationPolicy < BasePolicy
  def user_notifications?
    read?
  end

  def close?
    manage?
  end

  def view_notifications?
    owner? || superadmin?
  end

  private

  def owner?
    user.id == record.id
  end
end