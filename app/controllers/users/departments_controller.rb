class Users::DepartmentsController < ApplicationController
  skip_after_action :verify_authorized

  def edit
    @departments = if (current_user.superadmin? || current_user.able_to?(:access_all_departments))
                     Department.all
                   else
                     Department.in_city(current_user.city)
                   end
  end

  def update
    department = Department.find(params[:user][:department_id])
    change_user_department current_user, department
    redirect_to root_path
  end

  def schedule_prompt
    @scheduled_department = current_user.scheduled_department_for_today
    if @scheduled_department.blank? || @scheduled_department == current_user.department
      redirect_to root_path
    end
  end

  def schedule_change
    department = current_user.scheduled_department_for_today
    change_user_department current_user, department if department.present?
    redirect_to root_path
  end
end
