# frozen_string_literal: true

class DepartmentWorkingHoursController < ApplicationController
  before_action :require_superadmin

  def edit
    @department = Department.find(params[:department_id])
    @working_hours = build_working_hours_for_week
    render 'shared/show_modal_form'
  end

  def update
    @department = Department.find(params[:department_id])

    params[:working_hours]&.each do |day_of_week, attrs|
      wh = @department.working_hours.find_or_initialize_by(day_of_week: day_of_week.to_i)
      wh.assign_attributes(
        opens_at: attrs[:is_closed] == '1' ? nil : attrs[:opens_at],
        closes_at: attrs[:is_closed] == '1' ? nil : attrs[:closes_at],
        is_closed: attrs[:is_closed] == '1'
      )
      wh.save
    end
  end

  private

  def require_superadmin
    authorize :schedule, :batch_update?
    redirect_to root_path, alert: t('errors.access_denied') unless current_user.superadmin?
  end

  def build_working_hours_for_week
    (0..6).map do |day|
      @department.working_hours.find_by(day_of_week: day) ||
        @department.working_hours.build(day_of_week: day)
    end
  end
end
