class QueueItemPolicy < ApplicationPolicy
  def manage?
    superadmin?
  end
end