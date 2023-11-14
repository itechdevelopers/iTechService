class RecordEditsController < ApplicationController
  before_action :editable_params

  def index
    authorize RecordEdit
    @record_edits = RecordEdit.history_for_editable(editable_params)
    @modal = "record_edits_#{editable_params[:editable_id]}"
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  private

  def editable_params
    params.permit(:editable_type, :editable_id)
  end
end
