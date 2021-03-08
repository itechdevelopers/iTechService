# frozen_string_literal: true

class CashOperationsController < ApplicationController
  def index
    authorize CashOperation
    @cash_operations = policy_scope(CashOperation).created_desc.page(params[:page])
    respond_to do |format|
      format.html
    end
  end

  def show
    @cash_operation = find_record CashOperation
    respond_to do |format|
      format.html
    end
  end

  def new
    @cash_operation = authorize CashOperation.new(cash_operation_params)
    respond_to do |format|
      format.html
      format.js { render 'shared/show_modal_form' }
    end
  end

  def edit
    @cash_operation = find_record CashOperation
  end

  def create
    @cash_operation = authorize CashOperation.new(cash_operation_params)
    respond_to do |format|
      if @cash_operation.save
        format.html { redirect_to @cash_operation, notice: 'Cash operation was successfully created.' }
        format.js { flash.now[:notice] = t("cash_operations.created.#{@cash_operation.kind}") }
      else
        format.html { render action: 'new' }
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def update
    @cash_operation = find_record CashOperation
    respond_to do |format|
      if @cash_operation.update_attributes(params[:cash_operation])
        format.html { redirect_to @cash_operation, notice: 'Cash operation was successfully updated.' }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @cash_operation = find_record CashOperation
    # @cash_operation.destroy
    respond_to do |format|
      format.html { redirect_to cash_operations_url }
    end
  end

  def cash_operation_params
    params.require(:cash_operation).permit(:comment, :is_out, :value)
          # .permit(:cash_shift_id, :comment, :is_out, :user_id, :value)
  end
end
