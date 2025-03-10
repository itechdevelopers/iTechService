class ReportPolicy < ApplicationPolicy
  def index?
    superadmin? || has_reports_access? || able_to?(:view_reports)
  end

  def manage?
    superadmin? || has_reports_access? || able_to?(:view_reports)
  end

  def export?
    manage?
  end
end
