# frozen_string_literal: true

class SettingsController < ApplicationController
  def index
    authorize Setting
    @settings = Setting.all

    respond_to do |format|
      format.html
      format.json { render json: @settings }
    end
  end

  def new
    @setting = authorize Setting.new
    respond_to do |format|
      format.html
      format.json { render json: @setting }
    end
  end

  def edit
    @setting = find_record Setting
  end

  def create
    @setting = authorize Setting.new(setting_params)

    respond_to do |format|
      if @setting.save
        format.html { redirect_to settings_path, notice: t('settings.created') }
        format.json { render json: @setting, status: :created, location: @setting }
      else
        format.html { render action: 'new' }
        format.json { render json: @setting.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @setting = find_record Setting

    respond_to do |format|
      if @setting.update_attributes(params[:setting])
        format.html { redirect_to settings_path, notice: t('settings.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @setting.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @setting = find_record Setting
    @setting.destroy

    respond_to do |format|
      format.html { redirect_to settings_url }
      format.json { head :no_content }
    end
  end

  def setting_params
    params.require(:setting)
          .permit(:department_id, :name, :presentation, :value, :value_type)
  end
end
