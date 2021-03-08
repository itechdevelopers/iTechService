# frozen_string_literal: true

class InstallmentsController < ApplicationController
  def show
    @installment = find_record Installment

    respond_to do |format|
      format.html
      format.json { render json: @installment }
    end
  end

  def new
    @installment = authorize Installment.new

    respond_to do |format|
      format.html
      format.json { render json: @installment }
    end
  end

  def edit
    @installment = find_record Installment
  end

  def create
    @installment = authorize Installment.new(installment_params)

    respond_to do |format|
      if @installment.save
        format.html { redirect_to @installment, notice: 'Installment was successfully created.' }
        format.json { render json: @installment, status: :created, location: @installment }
        format.js { render 'shared/close_modal_form' }
      else
        format.html { render action: 'new' }
        format.json { render json: @installment.errors, status: :unprocessable_entity }
        format.js
      end
    end
  end

  def update
    @installment = find_record Installment

    respond_to do |format|
      if @installment.update_attributes(installment_params)
        format.html { redirect_to @installment, notice: 'Installment was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @installment.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @installment = find_record Installment
    @installment.destroy

    respond_to do |format|
      format.html { redirect_to installments_url }
      format.json { head :no_content }
    end
  end

  def installment_params
    params.require(:installment)
          .permit(:installment_plan_id, :paid_at, :value)
  end
end
