# frozen_string_literal: true

# Управление «табличкой» пакетов — админы/суперадмины. Водители сюда не ходят:
# им в Цикле 3 будет отдельная форма забора (PackageWithdrawalPolicy).
class PackageDesignPolicy < ApplicationPolicy
  # Базовый ApplicationPolicy разрешает CRUD только суперадмину (manage? =
  # superadmin?). Здесь открываем и обычным админам — они ведут склад пакетов.
  def index?
    any_admin?
  end

  def show?
    any_admin?
  end

  def create?
    any_admin?
  end

  def update?
    any_admin?
  end

  def destroy?
    any_admin?
  end
end
