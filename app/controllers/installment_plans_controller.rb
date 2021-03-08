# frozen_string_literal: true

class InstallmentPlansController < ApplicationController
  def show
    @installment_plan = find_record InstallmentPlan

    respond_to do |format|
      format.html
      format.json { render json: @installment_plan }
    end
  end

  def new
    @installment_plan = authorize InstallmentPlan.new

    respond_to do |format|
      format.html
      format.json { render json: @installment_plan }
    end
  end

  def edit
    @installment_plan = find_record InstallmentPlan
  end

  def create
    @installment_plan = authorize InstallmentPlan.new(installment_plan_params)

    respond_to do |format|
      if @installment_plan.save
        format.html { redirect_to @installment_plan, notice: 'Installment plan was successfully created.' }
        format.json { render json: @installment_plan, status: :created, location: @installment_plan }
      else
        format.html { render action: 'new' }
        format.json { render json: @installment_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @installment_plan = find_record InstallmentPlan

    respond_to do |format|
      if @installment_plan.update_attributes(params[:installment_plan])
        format.html { redirect_to @installment_plan, notice: 'Installment plan was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @installment_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @installment_plan = find_record InstallmentPlan
    @installment_plan.destroy

    respond_to do |format|
      format.html { redirect_to installment_plans_url }
      format.json { head :no_content }
    end
  end

  def installment_plan_params
    params.require(:installment_plan)
          .permit(:cost, :is_closed, :issued_at, :object, :user_id, installments: [:paid_at, :value, :installment_plan])
    # TODO: check nested attributes for: installments
  end
end
