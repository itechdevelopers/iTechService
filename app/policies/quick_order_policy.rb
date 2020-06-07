class QuickOrderPolicy < BasePolicy
  def show?
    view_everywhere? || same_department?
  end

  def create?
    any_manager?(:software, :media)
  end

  def update?
    superadmin? ||
      same_department? && any_manager?(:media) ||
      (has_role?(:software) && record.user_id == user.id)
  end

  def set_done?
    superadmin? ||
      same_department? && any_manager?(:software, :media)
  end

  def view_everywhere?
    superadmin? || able_to?(:view_quick_orders_and_free_jobs_everywhere)
  end

  class Scope < Scope
    def resolve
      if user.superadmin? || user.able_to?(:view_quick_orders_and_free_jobs_everywhere)
        scope.all
      else
        scope.in_department(user.department)
      end
    end
  end
end