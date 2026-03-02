class WaitingClientPolicy < ApplicationPolicy
  def create?
    true
  end

  def test_printing?
    true
  end

  def complete?
    true
  end

  def complete_and_pause?
    true
  end

  def archive?
    true
  end

  def assign_window?
    true
  end

  def reassign_window?
    true
  end
  
  def repeat_audio?
    true
  end
end
