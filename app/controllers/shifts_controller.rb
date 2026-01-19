# frozen_string_literal: true

class ShiftsController < ApplicationController
  def index
    authorize :schedule
    @city = City.find(params[:city_id])
    load_shifts
    @shift = @city.shifts.build
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @city = City.find(params[:city_id])
    @shift = @city.shifts.build(shift_params)
    @shift.save
    load_shifts
  end

  def destroy
    authorize :schedule
    @shift = Shift.find(params[:id])
    @city = @shift.city
    @shift.destroy
    load_shifts
  end

  private

  def load_shifts
    @shifts = @city.shifts.reorder(:position)
  end

  def shift_params
    params.require(:shift).permit(:name, :short_name, :start_time, :end_time, :position)
  end
end
