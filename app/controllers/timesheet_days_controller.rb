# frozen_string_literal: true

class TimesheetDaysController < ApplicationController
  def index
    authorize TimesheetDay
    @users = policy_scope(User).active.schedulable.in_city(current_department.city).id_asc
    @timesheet_date = (params[:date].present? ? params[:date].to_date : Date.current).beginning_of_month
    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    @timesheet_day = authorize TimesheetDay.new(timesheet_day_params)
    respond_to do |format|
      format.js { render 'show_form' }
      format.json { render json: @timesheet_day }
    end
  end

  def edit
    @timesheet_day = find_record TimesheetDay
    respond_to do |format|
      format.js { render 'show_form' }
    end
  end

  def create
    @timesheet_day = authorize TimesheetDay.new(timesheet_day_params)
    @data = { user: @timesheet_day.user, date: @timesheet_day.date }
    respond_to do |format|
      if @timesheet_day.save
        format.js { render 'update_cell' }
        format.json { render json: @timesheet_day, status: :created, location: @timesheet_day }
      else
        format.js { render 'show_form' }
        format.json { render json: @timesheet_day.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @timesheet_day = find_record TimesheetDay
    @data = { user: @timesheet_day.user, date: @timesheet_day.date }
    respond_to do |format|
      if @timesheet_day.update_attributes(timesheet_day_params)
        format.js { render 'update_cell' }
        format.json { head :no_content }
      else
        format.js { render 'show_form' }
        format.json { render json: @timesheet_day.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @timesheet_day = find_record TimesheetDay
    @data = { user: @timesheet_day.user, date: @timesheet_day.date }
    @timesheet_day.destroy
    respond_to do |format|
      format.js { render 'update_cell' }
      format.json { head :no_content }
    end
  end

  def timesheet_day_params
    params.require(:timesheet_day)
          .permit(:date, :status, :time, :user_id, :work_mins)
  end
end
