# frozen_string_literal: true

# Only the standalone page is policed here: the technician's own report goes
# through the task modal and rides on ServiceJobPolicy#repair?.
class BreakageReportPolicy < ApplicationPolicy
  def new?
    any_admin?
  end

  def create?
    new?
  end
end
