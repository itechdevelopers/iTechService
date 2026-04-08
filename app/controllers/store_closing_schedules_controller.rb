# frozen_string_literal: true

class StoreClosingSchedulesController < ApplicationController
  def show
    authorize :schedule, :index?
    @department = Department.find(params[:department_id])
    @week_start = parse_week_start

    @group = StoreClosingGroup.find_by(department: @department)

    if @group
      @query = StoreClosingQuery.new(
        city: current_city,
        department: @department,
        group: @group,
        week_start: @week_start
      )
    end

    respond_to do |format|
      format.js
    end
  end

  def assign
    authorize :schedule, :assign?
    @department = Department.find(params[:department_id])
    @user = User.find(params[:user_id])
    @date = Date.parse(params[:date])

    validation = StoreClosingAssignmentValidator.new(
      user: @user, department: @department, date: @date
    ).validate

    @warnings = validation[:warnings]

    if validation[:eligible]
      @entry = StoreClosingEntry.find_or_create_by!(
        department: @department, user: @user, date: @date
      ) do |e|
        e.assigned_by = current_user
      end
      @success = true
    else
      @success = false
    end

    @week_start = @date.beginning_of_week(:monday)
    @monthly_count = StoreClosingEntry.for_department(@department).for_month(@date).where(user_id: @user.id).count

    respond_to do |format|
      format.js
    end
  end

  def unassign
    authorize :schedule, :unassign?
    @department = Department.find(params[:department_id])
    @user = User.find(params[:user_id])
    @date = Date.parse(params[:date])

    entry = StoreClosingEntry.find_by(department: @department, user: @user, date: @date)
    entry&.destroy

    @week_start = @date.beginning_of_week(:monday)
    @monthly_count = StoreClosingEntry.for_department(@department).for_month(@date).where(user_id: @user.id).count

    respond_to do |format|
      format.js
    end
  end

  private

  def parse_week_start
    if params[:week_start].present?
      Date.parse(params[:week_start]).beginning_of_week(:monday)
    else
      Date.current.beginning_of_week(:monday)
    end
  end
end
