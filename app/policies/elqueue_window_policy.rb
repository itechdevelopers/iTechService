class ElqueueWindowPolicy < ApplicationPolicy
  def select_window?
    true
  end

  def free_window?
    admin? || superadmin?
  end

  def show_finish_service?
    true
  end

  def take_a_break?
    true
  end

  def return_from_break?
    true
  end
end