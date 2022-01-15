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
    department = Department.find(action_params.dig(:user, :department_id))
    change_user_department current_user, department
    redirect_to root_path
  end
end
