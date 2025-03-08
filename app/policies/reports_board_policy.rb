class ReportsBoardPolicy < ApplicationPolicy
  def assign_permissions?
    manage?
  end

  def revoke_permissions?
    manage?
  end

  def access_control?
    manage?
  end

  def manage?
    superadmin?
  end

  def sort?
    manage?
  end
end
