class UserPolicy < BasePolicy

  def index?
    read?
  end

  def show?
    (same_department? && read?) ||
      able_to?(:see_all_users)
  end

  def see_all_users?
    any_admin? || able_to?(:see_all_users)
  end

  def search?
    true
  end

  def finance?
    same_department? && able_to?(:manage_salary)
  end

  def manage_rights?
    superadmin?
  end

  def profile?; true; end

  def update_wish?
    owner?
  end

  def update_uniform?
    owner?
  end

  def update_user_settings?
    owner?
  end

  def update_photo?
    owner? || update?
  end

  def update_self?
    owner?
  end

  def update_elqueue_window?
    owner?
  end

  def duty_calendar?
    owner? ||
      same_department? && (manage_schedule? || any_manager?)
  end

  def staff_duty_schedule?
    manage_schedule?
  end

  def schedule?
    read?
  end

  def create_duty_day?
    same_department? && manage_schedule?
  end

  def destroy_duty_day?
    same_department? && manage_schedule?
  end

  def add_to_job_schedule?
    same_department? && manage_schedule?
  end

  def rating?; read?; end

  def bonuses?; read?; end

  def experience?
    superadmin? || able_to?(:manage_salary)
  end

  def remember_pause?
    any_admin?
  end

  def unset_remember_pause?
    any_admin?
  end

  private

  def owner?
    user.id == record.id
  end

  def manage_schedule?
    any_admin? || able_to?(:manage_schedule)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.superadmin? || user.able_to?(:see_all_users)

      if scope.column_names.include?('department_id')
        scope.where(department_id: user.department_id)
      else
        scope.in_department(user.department_id)
      end
    end
  end
end