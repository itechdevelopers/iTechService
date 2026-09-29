# frozen_string_literal: true

class LegalEntitiesController < ApplicationController
  def index
    authorize LegalEntity
    load_board
  end

  def new
    @legal_entity = authorize LegalEntity.new
    render 'shared/show_modal_form'
  end

  def create
    @legal_entity = authorize LegalEntity.new(legal_entity_params)
    @legal_entity.save
    load_board
    render 'save'
  end

  def edit
    @legal_entity = find_record LegalEntity
    render 'shared/show_modal_form'
  end

  def update
    @legal_entity = find_record LegalEntity
    @legal_entity.update(legal_entity_params)
    load_board
    render 'save'
  end

  def destroy
    @legal_entity = find_record LegalEntity

    if @legal_entity.destroy
      redirect_to legal_entities_path, notice: t('.destroyed')
    else
      redirect_to legal_entities_path, alert: @legal_entity.errors.full_messages.to_sentence
    end
  end

  def link
    @legal_entity = find_record LegalEntity
    @department = Department.find(params[:department_id])
    @legal_entity.link!(@department)
    load_board
  end

  def unlink
    authorize LegalEntity
    LegalEntity.unlink!(Department.find(params[:department_id]))
    load_board
  end

  def sample_act
    authorize LegalEntity
    department = Department.find(params[:department_id])
    pdf = CompletionActPdf.new(CompletionActSample.new(department), view_context, sample: true)

    send_data pdf.render,
              filename: "sample_completion_act_#{department.id}.pdf",
              type: 'application/pdf',
              disposition: 'inline'
  end

  private

  def load_board
    @legal_entities = LegalEntity.ordered
    @departments = Department.joins(:city).preload(:city, :legal_entity)
                             .reorder('cities.name ASC, departments.name ASC')
    @requisites = DepartmentRequisites.by_department(@departments)
    @global_requisites = DepartmentRequisites.global
  end

  def legal_entity_params
    params.require(:legal_entity).permit(:name, :ogrn_inn, :legal_address)
  end
end
