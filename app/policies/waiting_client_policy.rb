class WaitingClientPolicy < ApplicationPolicy
  def create?
    true
  end

  def complete?
    true
  end

  def assign_window?
    true
  end

  def reassign_window?
    true
  end
end
