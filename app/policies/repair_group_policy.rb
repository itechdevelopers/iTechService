class RepairGroupPolicy < CommonPolicy
  def update?
    any_admin?
  end

  def manage?
    any_admin?
  end
end
