# frozen_string_literal: true

class DepartmentScheduleConfigsController < ApplicationController
  def index
    authorize :schedule
    @city = City.find(params[:city_id])
    @departments = @city.departments.main_branches.includes(:schedule_config)
    render 'shared/show_modal_form'
  end

  def update
    authorize :schedule
    @config = DepartmentScheduleConfig.find(params[:id])
    @config.update(config_params)
    @city = @config.department.city
    @departments = @city.departments.main_branches.includes(:schedule_config)
  end

  def batch_update
    authorize :schedule
    @city = City.find(params[:city_id])

    params[:configs]&.each do |dept_id, config_attrs|
      department = Department.find(dept_id)
      config = department.schedule_config || department.build_schedule_config
      config.update(short_name: config_attrs[:short_name], color: config_attrs[:color])
    end

    @departments = @city.departments.main_branches.includes(:schedule_config)
    render :update
  end

  private

  def config_params
    params.require(:department_schedule_config).permit(:short_name, :color)
  end
end
