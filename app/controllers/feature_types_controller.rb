# frozen_string_literal: true

class FeatureTypesController < ApplicationController
  def index
    authorize FeatureType
    @feature_types = policy_scope(FeatureType).all

    respond_to do |format|
      format.html
      format.json { render json: @feature_types }
    end
  end

  def new
    @feature_type = authorize FeatureType.new
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @feature_type }
    end
  end

  def edit
    @feature_type = find_record FeatureType

    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @feature_type = authorize FeatureType.new(feature_type_params)

    respond_to do |format|
      if @feature_type.save
        format.html { redirect_to feature_types_path, notice: t('feature_types.created') }
        format.json { render json: @feature_type, status: :created, location: @feature_type }
      else
        format.html { render 'form' }
        format.json { render json: @feature_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @feature_type = find_record FeatureType

    respond_to do |format|
      if @feature_type.update_attributes(params[:feature_type])
        format.html { redirect_to feature_types_path, notice: t('feature_types.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @feature_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @feature_type = find_record FeatureType
    @feature_type.destroy

    respond_to do |format|
      format.html { redirect_to feature_types_url }
      format.json { head :no_content }
    end
  end

  def feature_type_params
    params.require(:feature_type).permit(:kind, :name)
  end
end
