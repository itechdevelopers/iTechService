# frozen_string_literal: true

class InventoriesController < ApplicationController
  def index
    authorize Inventory

    scope = policy_scope(Inventory).recent.includes(:store, :user, :department)
    scope = scope.where(store_id: params[:store_id]) if params[:store_id].present?
    scope = scope.where(status: params[:status]) if Inventory.statuses.key?(params[:status])

    @inventories = scope
  end

  def show
    @inventory = find_record Inventory
  end

  def new
    @inventory = authorize Inventory.new(sort_mode: :alphabetical)

    render 'form'
  end

  def create
    @inventory = authorize Inventory.new(inventory_params)
    @inventory.user = current_user

    if @inventory.save
      redirect_to @inventory, notice: t('.created', number: @inventory.number)
    else
      render 'form'
    end
  end

  def edit
    @inventory = find_record Inventory

    render 'form'
  end

  def update
    @inventory = find_record Inventory

    if @inventory.update(inventory_params)
      redirect_to @inventory, notice: t('.updated')
    else
      render 'form'
    end
  end

  def destroy
    @inventory = find_record Inventory
    number = @inventory.number
    @inventory.destroy

    redirect_to inventories_path, notice: t('.destroyed', number: number)
  end

  private

  def inventory_params
    params.require(:inventory).permit(
      :store_id, :sort_mode, :ignore_model_in_sort, :include_zero_remnants, :comment
    )
  end
end
