class ReportCardPolicy < ApplicationPolicy
  def update_annotation?
    superadmin?
  end
end
