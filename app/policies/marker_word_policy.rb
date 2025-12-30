class MarkerWordPolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  def create?
    superadmin?
  end

  def destroy?
    superadmin?
  end
end
