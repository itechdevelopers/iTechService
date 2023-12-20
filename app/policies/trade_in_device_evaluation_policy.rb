class TradeInDeviceEvaluationPolicy < BasePolicy
  def manage?
    superadmin? || able_to?(:manage_trade_in)
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def index?; true; end

  def bulk_update?
    manage?
  end
  
end