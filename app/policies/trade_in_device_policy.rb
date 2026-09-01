class TradeInDevicePolicy < BasePolicy
  def manage?
    superadmin?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def create?; true; end

  def index?; manage?; end

  def show?; true; end

  def print?; manage?; end

  def index_unconfirmed?
    manage?
  end

  class Scope < Scope
    def resolve
      user.superadmin? ? scope.all : scope.none
    end
  end
end
