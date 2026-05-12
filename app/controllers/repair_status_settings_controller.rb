class RepairStatusSettingsController < ApplicationController
  def show
    @setting = authorize RepairStatusSetting.instance
    @repair_statuses = RepairStatus.ordered
  end

  def update
    @setting = authorize RepairStatusSetting.instance

    if @setting.update(setting_params)
      redirect_to repair_status_settings_path, notice: t('.updated')
    else
      @repair_statuses = RepairStatus.ordered
      render :show
    end
  end

  def update_statuses
    authorize RepairStatusSetting.instance, :update?

    submitted = params.require(:repair_statuses).permit!.to_h
    errors = []

    RepairStatus.transaction do
      submitted.each do |id, attrs|
        status = RepairStatus.find(id)
        permitted = attrs.slice('name', 'color')
        next if permitted.empty?

        unless status.update(permitted)
          errors << "#{status.code}: #{status.errors.full_messages.join(', ')}"
        end
      end
      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      redirect_to repair_status_settings_path, alert: errors.join('; ')
    else
      redirect_to repair_status_settings_path, notice: t('.updated')
    end
  end

  private

  def setting_params
    params.require(:repair_status_setting)
          .permit(:attention_timeout_seconds, :escalation_timeout_seconds)
  end
end
