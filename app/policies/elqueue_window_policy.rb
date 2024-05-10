class ElqueueWindowPolicy < ApplicationPolicy
  def select_window?
    true
  end

  def show_finish_service?
    true
  end
end