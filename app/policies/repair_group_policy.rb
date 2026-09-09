class RepairGroupPolicy < CommonPolicy
  def manage?
    any_admin? || able_to?(:manage_repair_services)
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def archive?
    manage?
  end

  def unarchive?
    manage?
  end
end
