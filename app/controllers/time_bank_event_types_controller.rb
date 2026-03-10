# frozen_string_literal: true

class TimeBankEventTypesController < ApplicationController
  def index
    authorize :schedule
    load_event_types
    @event_type = TimeBankEventType.new
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @event_type = TimeBankEventType.new(event_type_params)
    @event_type.save
    load_event_types
  end

  def update
    authorize :schedule
    @event_type = TimeBankEventType.find(params[:id])
    @event_type.update(event_type_params)
    load_event_types
  end

  def destroy
    authorize :schedule
    @event_type = TimeBankEventType.find(params[:id])
    @event_type.destroy
    load_event_types
  end

  private

  def load_event_types
    @event_types = TimeBankEventType.ordered
  end

  def event_type_params
    params.require(:time_bank_event_type).permit(:name, :direction, :active, :position)
  end
end
