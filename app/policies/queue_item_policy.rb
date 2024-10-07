class QueueItemPolicy < ApplicationPolicy
  def manage?
    superadmin? || user.id == 330
  end

  def unarchive?
    manage?
  end
end