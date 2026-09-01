# frozen_string_literal: true

# Reuses the existing management-role boundary for internal KPI evidence.
class KpiAuditPolicy < ApplicationPolicy
  def index?
    any_manager?
  end

  alias analyze? index?
  alias show? index?
  alias video? index?
end
