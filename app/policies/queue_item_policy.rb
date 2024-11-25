class QueueItemPolicy < ApplicationPolicy
  def manage?
    superadmin? || user.id == 330
  end

  def unarchive?
    manage?
  end

  def update_windows?
    any_admin?
  end
end
