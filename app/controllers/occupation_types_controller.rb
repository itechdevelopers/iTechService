# frozen_string_literal: true

class OccupationTypesController < ApplicationController
  def index
    authorize :schedule
    @city = City.find(params[:city_id])
    load_occupation_types
    @occupation_type = @city.occupation_types.build
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @city = City.find(params[:city_id])
    @occupation_type = @city.occupation_types.build(occupation_type_params)
    @occupation_type.save
    load_occupation_types
  end

  def destroy
    authorize :schedule
    @occupation_type = OccupationType.find(params[:id])
    @city = @occupation_type.city
    @occupation_type.destroy
    load_occupation_types
  end

  private

  def load_occupation_types
    @occupation_types = @city.occupation_types.reorder(:position)
  end

  def occupation_type_params
    params.require(:occupation_type).permit(:name, :color, :counts_as_working, :position)
  end
end
