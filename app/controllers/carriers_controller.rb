# frozen_string_literal: true

class CarriersController < ApplicationController
  def index
    authorize Carrier
    @carriers = policy_scope(Carrier).all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @carriers }
    end
  end

  def new
    @carrier = authorize Carrier.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @carrier }
    end
  end

  def edit
    @carrier = find_record Carrier
  end

  def create
    @carrier = authorize Carrier.new(carrier_params)

    respond_to do |format|
      if @carrier.save
        format.html { redirect_to carriers_path, notice: 'Carrier was successfully created.' }
        format.json { render json: @carrier, status: :created, location: @carrier }
      else
        format.html { render action: 'new' }
        format.json { render json: @carrier.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @carrier = find_record Carrier

    respond_to do |format|
      if @carrier.update_attributes(carrier_params)
        format.html { redirect_to carriers_path, notice: 'Carrier was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @carrier.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @carrier = find_record Carrier
    @carrier.destroy

    respond_to do |format|
      format.html { redirect_to carriers_url }
      format.json { head :no_content }
    end
  end

  def carrier_params
    params.require(:carrier).permit(:name)
  end
end
