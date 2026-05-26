class PlanPolicy < ApplicationPolicy
  def update?
    superadmin?
  end
end
