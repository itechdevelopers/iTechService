class ReportsBoardPolicy < ApplicationPolicy
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
