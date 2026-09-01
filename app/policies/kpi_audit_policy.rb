# frozen_string_literal: true

# KPI investigations are restricted to the existing superadmin role.
class KpiAuditPolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  alias analyze? index?
  alias show? index?
  alias video? index?
  alias clip? index?
end
