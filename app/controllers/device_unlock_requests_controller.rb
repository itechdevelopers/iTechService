# frozen_string_literal: true

class DeviceUnlockRequestsController < ApplicationController
  def index
    authorize DeviceUnlockRequest
    @device_unlock_requests =
      DeviceUnlockRequest.recent.includes(:client, :item, :comments)
  end

  def show
    @device_unlock_request = find_record DeviceUnlockRequest
  end

  def new
    @device_unlock_request = authorize DeviceUnlockRequest.new
  end

  def create
    @device_unlock_request = authorize DeviceUnlockRequest.new(device_unlock_request_params)
    # Автор и департамент — на сервере (как в приёмке / client_requests#create).
    # status берёт дефолт из БД (0 = new_request, см. миграцию).
    @device_unlock_request.user = current_user
    @device_unlock_request.department = current_user.department

    if @device_unlock_request.save
      redirect_to device_unlock_requests_path, notice: t('.created')
    else
      render :new
    end
  end

  # Смена workflow-статуса кнопкой-ссылкой remote:true. find_record авторизует
  # через update_status? (action_name → одноимённый предикат policy).
  def update_status
    @device_unlock_request = find_record DeviceUnlockRequest

    if @device_unlock_request.update(status_params)
      respond_to do |format|
        format.js   # перерисовывает строку #device_unlock_request_<id>
        format.html { redirect_to device_unlock_requests_path, notice: t('.updated') }
      end
    else
      head :unprocessable_entity
    end
  end

  # История изменений (иконка часов) — читает HistoryRecord, как в clients#history.
  def history
    @device_unlock_request = find_record DeviceUnlockRequest
    @records = @device_unlock_request.history_records.order(created_at: :desc)
    render 'shared/show_history'
  end

  private

  def device_unlock_request_params
    params.require(:device_unlock_request).permit(:client_id, :item_id, :reason)
  end

  def status_params
    params.require(:device_unlock_request).permit(:status)
  end
end
