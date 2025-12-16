# frozen_string_literal: true

class ServiceConditionsController < ApplicationController
  def index
    authorize ServiceCondition
    @service_conditions = ServiceCondition.all
  end

  def new
    @service_condition = authorize ServiceCondition.new
  end

  def edit
    @service_condition = find_record ServiceCondition
  end

  def create
    @service_condition = authorize ServiceCondition.new(service_condition_params)

    if @service_condition.save
      redirect_to service_conditions_path, notice: t('service_conditions.created')
    else
      render action: 'new'
    end
  end

  def update
    @service_condition = find_record ServiceCondition

    if @service_condition.update(service_condition_params)
      redirect_to service_conditions_path, notice: t('service_conditions.updated')
    else
      render action: 'edit'
    end
  end

  def destroy
    @service_condition = find_record ServiceCondition
    @service_condition.destroy

    redirect_to service_conditions_url, notice: t('service_conditions.deleted')
  end

  private

  def service_condition_params
    params.require(:service_condition).permit(:content, :position)
  end
end
