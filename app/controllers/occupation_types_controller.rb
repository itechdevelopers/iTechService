# frozen_string_literal: true

class OccupationTypesController < ApplicationController
  def index
    authorize :schedule
    load_occupation_types
    @occupation_type = OccupationType.new
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @occupation_type = OccupationType.new(occupation_type_params)
    @occupation_type.save
    load_occupation_types
  end

  def destroy
    authorize :schedule
    @occupation_type = OccupationType.find(params[:id])
    @occupation_type.destroy
    load_occupation_types
  end

  private

  def load_occupation_types
    @occupation_types = OccupationType.reorder(:position)
  end

  def occupation_type_params
    params.require(:occupation_type).permit(:name, :color, :counts_as_working, :position)
  end
end
