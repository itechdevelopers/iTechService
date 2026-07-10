# frozen_string_literal: true

# Управление «табличкой» пакетов — админы/суперадмины. Водители сюда не ходят:
# им в Цикле 3 будет отдельная форма забора (PackageWithdrawalPolicy).
class PackageDesignPolicy < ApplicationPolicy
  def index?
    any_admin?
  end
end
