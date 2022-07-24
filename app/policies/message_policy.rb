class MessagePolicy < ApplicationPolicy
  def create?
    true
  end

  def read?
    true
  end
end