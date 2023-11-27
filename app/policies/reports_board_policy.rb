class ReportsBoardPolicy < ApplicationPolicy
  def manage?
    superadmin?
  end

  def sort?
    manage?
  end
end