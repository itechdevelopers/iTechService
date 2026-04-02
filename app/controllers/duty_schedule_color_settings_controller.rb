# frozen_string_literal: true

class DutyScheduleColorSettingsController < ApplicationController
  def index
    authorize :schedule
    load_settings
    render 'shared/show_modal_form'
  end

  def update
    authorize :schedule
    @setting = DutyScheduleColorSetting.find(params[:id])
    @setting.update(setting_params)
    Rails.cache.delete('duty_schedule_color_settings')
    load_settings
  end

  private

  def load_settings
    @color_settings = DutyScheduleColorSetting.order(:id)
  end

  def setting_params
    params.require(:duty_schedule_color_setting).permit(:color)
  end
end
