class QuickOrderPolicy < BasePolicy
  def show?
    view_everywhere? || same_department? || able_to?(:access_all_departments)
  end

  def create?
    any_manager?(:software, :media, :universal) || able_to?(:access_all_departments)
  end

  def update?
    superadmin? ||
      same_department? && any_manager?(:media, :universal) ||
      (has_role?(:software, :universal) && record.user_id == user.id) || able_to?(:access_all_departments)
  end

  def set_done?
    superadmin? ||
      same_department? && any_manager?(:software, :media, :universal) || able_to?(:access_all_departments)
  end

  def history?
    show?
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
