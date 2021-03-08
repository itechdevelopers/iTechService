# frozen_string_literal: true

class CashDrawersController < ApplicationController
  def index
    authorize CashDrawer
    @cash_drawers = policy_scope(CashDrawer).all
    respond_to do |format|
      format.html
    end
  end

  def show
    @cash_drawer = find_record CashDrawer
    respond_to do |format|
      format.html
    end
  end

  def new
    @cash_drawer = authorize CashDrawer.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @cash_drawer = find_record CashDrawer
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @cash_drawer = authorize CashDrawer.new(cash_drawer_params)
    respond_to do |format|
      if @cash_drawer.save
        format.html { redirect_to @cash_drawer, notice: 'Cash drawer was successfully created.' }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @cash_drawer = find_record CashDrawer
    respond_to do |format|
      if @cash_drawer.update_attributes(params[:cash_drawer])
        format.html { redirect_to @cash_drawer, notice: 'Cash drawer was successfully updated.' }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @cash_drawer = find_record CashDrawer
    @cash_drawer.destroy
    respond_to do |format|
      format.html { redirect_to cash_drawers_url }
    end
  end

  def cash_drawer_params
    params.require(:cash_drawer).permit(:department_id, :name)
  end
end
