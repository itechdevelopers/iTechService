class WaitingClientPolicy < ApplicationPolicy
  def create?
    true
  end

  def complete?
    true
  end
end