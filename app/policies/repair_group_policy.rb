class RepairGroupPolicy < CommonPolicy
  def update?
    superadmin?
  end

  def manage?
    superadmin?
  end
end
