class SchedulePolicy < ApplicationPolicy
  # View access: any authenticated user
  def index?
    user.present?
  end

  def show?
    index?
  end

  # Management access: superadmin or users with manage_schedules ability
  def manage?
    superadmin? || able_to?(:manage_schedules)
  end

  def create?
    manage?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  def batch_update?
    manage?
  end

  def upsert?
    manage?
  end

  def batch_upsert?
    manage?
  end

  def batch_destroy?
    manage?
  end

  def history?
    manage?
  end

  def save_week?
    manage?
  end

  def create_memo?
    manage?
  end

  def update_memo?
    manage?
  end

  def destroy_memo?
    manage?
  end
end
