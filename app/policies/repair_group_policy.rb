class RepairGroupPolicy < CommonPolicy
  def update?
    any_admin?
  end

  def destroy?
    any_admin?
  end

  def manage?
    any_admin?
  end

  def archive?
    any_admin?
  end

  def unarchive?
    any_admin?
  end
end
