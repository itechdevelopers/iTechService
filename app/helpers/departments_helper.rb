module DepartmentsHelper
  def department_roles_for_select
    Department::ROLES.to_a.map { |r| [t("departments.roles.#{r[1]}"), r[0]] }
  end

  def human_department_role(department)
    t "departments.roles.#{department.role_s}"
  end

  def local_departments_collection
    Department.selectable.in_city(current_user.city)
  end

  def current_department_link
    link_to current_department.name, edit_user_department_path,
            id: 'current_department_name', class: 'city_tag',
            style: "background-color: #{current_department.color}"
  end

  def department_tag(department)
    content_tag :span, department.name, class: 'city_tag',
                style: "background-color: #{department.color}"
  end

  def department_options_for_select
    options_from_collection_for_select Department.selectable, :id, :name, params[:department_id]
  end

  def real_departments
    Department.real.participating_in_repair_services
  end
end
