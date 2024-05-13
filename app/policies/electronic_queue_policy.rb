class ElectronicQueuePolicy < ApplicationPolicy
  def manage?
    superadmin? || user.id == 330
  end

  def index?
    manage?
  end

  def ipad_show?
    true
  end

  def show_active_tickets?
    true
  end
end