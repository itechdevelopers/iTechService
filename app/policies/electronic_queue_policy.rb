class ElectronicQueuePolicy < ApplicationPolicy
  def manage?
    superadmin? || user.id == 330
  end

  def manage_windows?
    admin? || superadmin?
  end

  def update_windows?
    any_admin?
  end

  def control_panel?
    any_admin?
  end

  def monitoring?
    true
  end

  def index?
    manage?
  end

  def ipad_show?
    true
  end

  def tv_show?
    true
  end

  def show_active_tickets?
    true
  end

  def manage_tickets?
    true
  end

  def sort_tickets?
    true
  end

  def return_old_ticket?
    true
  end
end