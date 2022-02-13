# frozen_string_literal: true

class LocationsController < ApplicationController
  def index
    authorize Location
    @locations = policy_scope(Location).search(search_params).ordered

    respond_to do |format|
      format.html
      format.js
      format.json { render json: @locations }
    end
  end

  def new
    @location = authorize Location.new

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @location }
    end
  end

  def edit
    @location = find_record Location
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @location = authorize Location.new(location_params)

    respond_to do |format|
      if @location.save
        format.html { redirect_to locations_path, notice: t('locations.created') }
        format.json { render json: @location, status: :created, location: @location }
      else
        format.html { render 'form' }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @location = find_record Location

    respond_to do |format|
      if @location.update_attributes(location_params)
        format.html { redirect_to locations_path, notice: t('locations.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @location = find_record Location
    @location.destroy

    respond_to do |format|
      format.html { redirect_to locations_url }
      format.json { head :no_content }
    end
  end

  def location_params
    params.require(:location)
          .permit(:ancestry, :code, :department_id, :hidden, :name, :position, :schedule, :storage_term)
  end
end
