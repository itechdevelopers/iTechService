# frozen_string_literal: true

class TestingTemplatesController < ApplicationController
  def index
    authorize TestingTemplate
    @testing_templates = policy_scope(TestingTemplate).ordered
    respond_to do |format|
      format.html
    end
  end

  def new
    @testing_template = authorize TestingTemplate.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @testing_template = find_record TestingTemplate
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @testing_template = authorize TestingTemplate.new(testing_template_params)
    respond_to do |format|
      if @testing_template.save
        format.html { redirect_to testing_templates_path, notice: t('testing_templates.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @testing_template = find_record TestingTemplate
    respond_to do |format|
      if @testing_template.update_attributes(testing_template_params)
        format.html { redirect_to testing_templates_path, notice: t('testing_templates.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @testing_template = find_record TestingTemplate
    @testing_template.destroy
    respond_to do |format|
      format.html { redirect_to testing_templates_url }
    end
  end

  private

  def testing_template_params
    params.require(:testing_template)
          .permit(:content, :position)
  end
end
