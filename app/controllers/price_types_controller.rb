# frozen_string_literal: true

class PriceTypesController < ApplicationController
  before_action :set_price_type, only: %i[edit update destroy]

  def index
    authorize PriceType
    @price_types = policy_scope(PriceType).all

    respond_to do |format|
      format.html
      format.json { render json: @price_types }
    end
  end

  def new
    @price_type = PriceType.new

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @price_type }
    end
  end

  def edit
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @price_type }
    end
  end

  def create
    @price_type = authorize PriceType.new(price_type_params)

    respond_to do |format|
      if @price_type.save
        format.html { redirect_to price_types_path, notice: 'Price type was successfully created.' }
        format.json { render json: @price_type, status: :created, location: @price_type }
      else
        format.html { render 'form' }
        format.json { render json: @price_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @price_type.update_attributes(params[:price_type])
        format.html { redirect_to price_types_path, notice: 'Price type was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @price_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @price_type.destroy

    respond_to do |format|
      format.html { redirect_to price_types_url }
      format.json { head :no_content }
    end
  end

  private

  def set_price_type
    @price_type = find_record PriceType
  end

  def price_type_params
    params.require(:price_type)
          .permit(:kind, :name)
  end
end
