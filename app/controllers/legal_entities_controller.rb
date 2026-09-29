# frozen_string_literal: true

class LegalEntitiesController < ApplicationController
  def index
    authorize LegalEntity
    @legal_entities = LegalEntity.ordered
  end

  def new
    @legal_entity = authorize LegalEntity.new
    render 'shared/show_modal_form'
  end

  def create
    @legal_entity = authorize LegalEntity.new(legal_entity_params)
    @legal_entity.save
    render_save_response
  end

  def edit
    @legal_entity = find_record LegalEntity
    render 'shared/show_modal_form'
  end

  def update
    @legal_entity = find_record LegalEntity
    @legal_entity.update(legal_entity_params)
    render_save_response
  end

  def destroy
    @legal_entity = find_record LegalEntity

    if @legal_entity.destroy
      redirect_to legal_entities_path, notice: t('.destroyed')
    else
      redirect_to legal_entities_path, alert: @legal_entity.errors.full_messages.to_sentence
    end
  end

  private

  def render_save_response
    @legal_entities = LegalEntity.ordered
    render 'save'
  end

  def legal_entity_params
    params.require(:legal_entity).permit(:name, :ogrn_inn, :legal_address)
  end
end
