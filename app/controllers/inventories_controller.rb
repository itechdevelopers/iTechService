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
end
