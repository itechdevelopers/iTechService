# frozen_string_literal: true

class BonusTypesController < ApplicationController
  def index
    authorize BonusType
    @bonus_types = policy_scope(BonusType).all
    respond_to do |format|
      format.html
    end
  end

  def new
    @bonus_type = authorize BonusType.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @bonus_type = find_record BonusType
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @bonus_type = authorize BonusType.new(bonus_type_params)
    respond_to do |format|
      if @bonus_type.save
        format.html { redirect_to bonus_types_path, notice: t('bonus_types.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @bonus_type = find_record BonusType
    respond_to do |format|
      if @bonus_type.update_attributes(params[:bonus_type])
        format.html { redirect_to bonus_types_path, notice: t('bonus_types.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @bonus_type = find_record BonusType
    @bonus_type.destroy
    respond_to do |format|
      format.html { redirect_to bonus_types_url }
    end
  end

  def bonus_type_params
    params.require(:bonus_type)
          .permit(:name)
  end
end
