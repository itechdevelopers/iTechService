class QueueItemPolicy < ApplicationPolicy
  def manage?
    superadmin? || user.id == 330
  end
end