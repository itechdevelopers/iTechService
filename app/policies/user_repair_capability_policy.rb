# frozen_string_literal: true

class UserRepairCapabilityPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    any_admin?
  end

  def destroy?
    any_admin?
  end
end
