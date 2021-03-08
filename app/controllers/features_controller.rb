# frozen_string_literal: true

class FeaturesController < ApplicationController
  def index
    authorize Feature
    @features = Feature.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @features }
    end
  end

  def show
    @feature = find_record Feature

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @feature }
    end
  end

  def new
    @feature = authorize Feature.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @feature }
    end
  end

  def edit
    @feature = find_record Feature
  end

  def create
    @feature = authorize Feature.new(feature_params)

    respond_to do |format|
      if @feature.save
        format.html { redirect_to @feature, notice: 'Feature was successfully created.' }
        format.json { render json: @feature, status: :created, location: @feature }
      else
        format.html { render action: 'new' }
        format.json { render json: @feature.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @feature = find_record Feature

    respond_to do |format|
      if @feature.update_attributes(params[:feature])
        format.html { redirect_to @feature, notice: 'Feature was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @feature.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @feature = find_record Feature
    @feature.destroy

    respond_to do |format|
      format.html { redirect_to features_url }
      format.json { head :no_content }
    end
  end

  def feature_params
    params.require(:feature)
          .permit(:feature_type_id, :item_id, :value)
  end
end
