class FaultPolicy < ApplicationPolicy
  def read?
    same_department? && (manage? || (record.causer_id == user.id))
  end

  def manage?
    any_admin?
  end

  def create?
    manage?
  end

  def update?
    same_department? && manage?
  end

  def destroy?
    superadmin?
  end

  # Обмен минуса на плюсы жмётся ТОЛЬКО владельцем учётки (защита от мискликов
  # старших). Доступен лишь для обменяемых видов и ещё не обменянных минусов.
  def exchange?
    record.causer_id == user.id &&
      record.kind&.exchangeable? &&
      !record.exchanged?
  end

  # Откат обмена — только superadmin (реализуется в Цикле 4).
  def unexchange?
    superadmin?
  end
end
