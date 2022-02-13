# frozen_string_literal: true

class RepairGroupsController < ApplicationController
  def index
    authorize RepairGroup
    @repair_groups = RepairGroup.roots.order('id asc')
    respond_to do |format|
      format.js
    end
  end

  def show
    @repair_group = find_record RepairGroup
    @repair_services = @repair_group.repair_services
    params[:table_name] = 'repair_services/choose_table' if params[:mode] == 'choose'
    respond_to do |format|
      format.js
    end
  end

  def new
    @repair_group = authorize RepairGroup.new
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def edit
    @repair_group = find_record RepairGroup
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def create
    @repair_group = authorize RepairGroup.new(repair_group_params)
    @repair_groups = RepairGroup.roots.order('id asc')
    respond_to do |format|
      if @repair_group.save
        format.js
      else
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def update
    @repair_group = find_record RepairGroup
    @repair_groups = RepairGroup.roots.order('id asc')
    respond_to do |format|
      if @repair_group.update_attributes(repair_group_params)
        format.js
      else
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    @repair_group = find_record RepairGroup
    @repair_group.destroy
    respond_to do |format|
      format.js { head :no_content }
    end
  end

  def repair_group_params
    params.require(:repair_group)
          .permit(:ancestry, :ancestry_depth, :name, :parent_id)
  end
end
