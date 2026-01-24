class SchedulePolicy < ApplicationPolicy
  def index?
    superadmin? || able_to?(:manage_schedules)
  end

  def manage?
    index?
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end

  def batch_update?
    index?
  end

  def upsert?
    index?
  end
end
