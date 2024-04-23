class ElectronicQueuePolicy < ApplicationPolicy
  def manage?
    superadmin?
  end

  def index?
    manage?
  end
end