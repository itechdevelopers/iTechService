class RepairCausesController < ApplicationController

  def new
    authorize RepairCause
    @modal = "repair_causes"
    @repair_cause = RepairCause.new
    respond_to do |format|
      format.js { render "shared/show_modal_form" }
    end
  end

  def create
    @repair_cause = authorize RepairCause.new(repair_cause_params) 
    if new_rcg_params[:repair_cause_group_name].present?
      group_title = new_rcg_params[:repair_cause_group_name]
      new_repair_cause_group = RepairCauseGroup.find_or_create_by(title: group_title)
      @repair_cause.repair_cause_group_id = new_repair_cause_group.id
    end

    respond_to do |format|
      if @repair_cause.save
        format.js
      else
        format.js { render "shared/show_modal_form" }
      end
    end
  end

  private

  def new_rcg_params
    params.require(:repair_cause).permit(:repair_cause_group_name)
  end

  def repair_cause_params
    params.require(:repair_cause).permit(:title, :repair_cause_group_id)
  end
end
