# frozen_string_literal: true

class PhoneLabelPolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  def create?
    superadmin?
  end

  def destroy?
    superadmin?
  end
end
