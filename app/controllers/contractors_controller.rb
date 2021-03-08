# frozen_string_literal: true

class ContractorsController < ApplicationController
  def index
    authorize Contractor
    @contractors = policy_scope(Contractor).all

    respond_to do |format|
      format.html
      format.json { render json: @contractors }
    end
  end

  def show
    @contractor = find_record Contractor

    respond_to do |format|
      format.html
      format.json { render json: @contractor }
    end
  end

  def new
    @contractor = authorize Contractor.new

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @contractor }
    end
  end

  def edit
    @contractor = find_record Contractor

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @contractor }
    end
  end

  def create
    @contractor = authorize Contractor.new(contractor_params)

    respond_to do |format|
      if @contractor.save
        format.html { redirect_to contractors_path, notice: t('contractors.created') }
        format.json { render json: @contractor, status: :created, location: @contractor }
      else
        format.html { render 'form' }
        format.json { render json: @contractor.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @contractor = find_record Contractor

    respond_to do |format|
      if @contractor.update_attributes(params[:contractor])
        format.html { redirect_to contractors_path, notice: t('contractors.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @contractor.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @contractor = find_record Contractor
    @contractor.destroy

    respond_to do |format|
      format.html { redirect_to contractors_url }
      format.json { head :no_content }
    end
  end

  def contractor_params
    params.require(:contractor).permit(:name)
  end
end
