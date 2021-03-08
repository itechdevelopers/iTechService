# frozen_string_literal: true

class PricesController < ApplicationController
  def index
    authorize Price
    @prices = policy_scope(Price).all

    respond_to do |format|
      format.html
      format.json { render json: @prices }
    end
  end

  def show
    @price = find_record Price

    respond_to do |format|
      format.html
      format.json { render json: @price }
    end
  end

  def new
    @price = authorize Price.new

    respond_to do |format|
      format.html
      format.json { render json: @price }
    end
  end

  def edit
    @price = find_record Price
  end

  def create
    @price = authorize Price.new(price_params)

    respond_to do |format|
      if @price.save
        format.html { redirect_to prices_url, notice: t('prices.created') }
        format.json { render json: @price, status: :created, location: @price }
      else
        format.html { render action: 'new' }
        format.json { render json: @price.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @price = find_record Price

    respond_to do |format|
      if @price.update_attributes(price_params)
        format.html { redirect_to prices_url, notice: t('prices.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @price.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @price = find_record Price
    @price.destroy

    respond_to do |format|
      format.html { redirect_to prices_url }
      format.json { head :no_content }
    end
  end

  def price_params
    params.require(:price)
          .permit(:department_id, :file)
  end
end
