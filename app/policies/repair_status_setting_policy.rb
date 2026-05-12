class RepairStatusSettingPolicy < ApplicationPolicy
  def show?
    user.superadmin?
  end

  def update?
    user.superadmin?
  end
end
