# frozen_string_literal: true

class SchedulesController < ApplicationController
  def index
    authorize :schedule
    @city = current_city
    @departments = @city.departments.includes(:working_hours)
    @schedule_groups = @city.schedule_groups.includes(:owner, :members)
  end

  private

  def current_city
    if params[:city_id].present?
      City.find(params[:city_id])
    else
      current_user.city || City.first
    end
  end
end
