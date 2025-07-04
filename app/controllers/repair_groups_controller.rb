# frozen_string_literal: true

class RepairGroupsController < ApplicationController
  def index
    authorize RepairGroup
    @repair_groups = RepairGroup.not_archived.roots.order('id asc')
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
    @repair_groups = RepairGroup.not_archived.roots.order('id asc')
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
    @repair_groups = RepairGroup.not_archived.roots.order('id asc')

    parent_id_param = repair_group_params[:parent_id]
    if parent_id_param == 'nil'
      @repair_group.parent = nil
      @repair_group.save!
    else
      @repair_group.update_attributes(repair_group_params.slice(:parent_id))
    end

    respond_to do |format|
      if @repair_group.update_attributes(repair_group_params.except(:parent_id))
        format.js
      else
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    @repair_group = find_record RepairGroup
    @repair_groups = RepairGroup.not_archived.roots.order('id asc')
    
    respond_to do |format|
      if @repair_group.safe_destroy
        format.js { render 'destroy' }
        format.json { head :no_content }
      else
        format.js { render 'destroy', status: :unprocessable_entity }
        format.json { render json: { errors: @repair_group.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  rescue StandardError => e
    @repair_group.errors.add(:base, "Произошла непредвиденная ошибка при удалении группы ремонта")
    respond_to do |format|
      format.js { render 'destroy', status: :internal_server_error }
      format.json { render json: { errors: @repair_group.errors.full_messages }, status: :internal_server_error }
    end
  end

  def archive
    @repair_group = find_record RepairGroup
    archive_errors = @repair_group.can_be_archived?
    
    respond_to do |format|
      if archive_errors.empty?
        @repair_group.archive_with_descendants!
        @repair_groups = RepairGroup.not_archived.roots.order('id asc')
        @archived_repair_groups = RepairGroup.archived_for_display.sort_by(&:id)
        format.js
      else
        @repair_group.errors.add(:base, archive_errors.join("; "))
        format.js { render 'archive', status: :unprocessable_entity }
      end
    end
  rescue StandardError => e
    @repair_group.errors.add(:base, "Произошла ошибка при архивировании группы ремонта")
    respond_to do |format|
      format.js { render 'archive', status: :internal_server_error }
    end
  end

  def unarchive
    @repair_group = find_record RepairGroup
    unarchive_errors = @repair_group.can_be_unarchived?
    
    respond_to do |format|
      if unarchive_errors.empty?
        @repair_group.unarchive_with_ancestors!
        @repair_groups = RepairGroup.not_archived.roots.order('id asc')
        @archived_repair_groups = RepairGroup.archived_for_display.sort_by(&:id)
        format.js
      else
        @repair_group.errors.add(:base, unarchive_errors.join("; "))
        format.js { render 'unarchive', status: :unprocessable_entity }
      end
    end
  rescue StandardError => e
    @repair_group.errors.add(:base, "Произошла ошибка при восстановлении группы ремонта")
    respond_to do |format|
      format.js { render 'unarchive', status: :internal_server_error }
    end
  end

  def archived
    authorize RepairGroup
    @archived_repair_groups = RepairGroup.archived_for_display.sort_by(&:id)
    respond_to do |format|
      format.js
    end
  end

  def repair_group_params
    params.require(:repair_group)
          .permit(:ancestry, :ancestry_depth, :name, :parent_id)
  end
end
