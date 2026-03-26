# frozen_string_literal: true

class FindMyDeviceChecksController < ApplicationController
  def index
    authorize FindMyDeviceCheck
    @enabled = Setting.find_my_device_check_enabled?
    @checks = FindMyDeviceCheck.recent_first
                               .includes(:user, :service_job)
                               .page(params[:page])
                               .per(50)
  end

  def check
    authorize FindMyDeviceCheck
    imei = params[:imei]

    if imei.blank?
      return render json: { success: false, error: 'IMEI не указан' }, status: :unprocessable_entity
    end

    unless Setting.find_my_device_check_enabled?
      return render json: { success: true, skip: true, message: 'Проверка отключена' }
    end

    if FindMyDeviceCheck.imei_blocked?(imei)
      return render json: { success: false, blocked: true,
                            error: 'Функция «Найти iPhone» была включена. Повторная проверка доступна через 5 минут.' }
    end

    result = FindMyDeviceCheckService.call(imei: imei)

    check_record = FindMyDeviceCheck.create!(
      imei: imei,
      user: current_user,
      service_job_id: params[:service_job_id],
      status: result[:success] ? (result[:locked] ? :locked : :unlocked) : :error,
      api_response: result[:raw_result] || result[:error]
    )

    if result[:success]
      if result[:locked]
        render json: { success: false, locked: true,
                       error: 'Функция «Найти iPhone» включена. Создание невозможно. Повторная попытка через 5 минут.' }
      else
        render json: { success: true, locked: false }
      end
    else
      render json: { success: false, error: result[:error] }
    end
  end

  def toggle
    authorize FindMyDeviceCheck
    setting = Setting.find_or_initialize_by(name: 'find_my_device_check_enabled', department_id: nil)
    setting.value = setting.value == '1' ? '0' : '1'
    setting.value_type = 'boolean'
    setting.presentation = I18n.t('settings.find_my_device_check_enabled')
    setting.save!

    redirect_to find_my_device_checks_path, notice: "Проверка #{setting.value == '1' ? 'включена' : 'выключена'}"
  end
end
