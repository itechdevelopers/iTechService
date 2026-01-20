# frozen_string_literal: true

class ShiftsController < ApplicationController
  def index
    authorize :schedule
    load_shifts
    @shift = Shift.new
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @shift = Shift.new(shift_params)
    @shift.save
    load_shifts
  end

  def destroy
    authorize :schedule
    @shift = Shift.find(params[:id])
    @shift.destroy
    load_shifts
  end

  private

  def load_shifts
    @shifts = Shift.reorder(:position)
  end

  def shift_params
    params.require(:shift).permit(:name, :short_name, :start_time, :end_time, :position)
  end
end
