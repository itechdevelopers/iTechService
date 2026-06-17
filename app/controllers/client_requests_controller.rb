# frozen_string_literal: true

class ClientRequestsController < ApplicationController
  def index
    authorize ClientRequest
    @client_requests = ClientRequest.recent.includes(:client, :item)
  end

  def show
    @client_request = find_record ClientRequest
  end

  def new
    @client_request = authorize ClientRequest.new
  end

  def create
    @client_request = authorize ClientRequest.new(client_request_params)
    # Автор и департамент — на сервере (как в приёмке, service_jobs#create).
    # kind/status/purchase_check_status берут дефолты из БД: 0/0/0 =
    # receipt_search / new_request / pending (см. миграцию create_client_requests).
    @client_request.user = current_user
    @client_request.department = current_user.department

    if @client_request.save
      redirect_to client_requests_path, notice: t('.created')
    else
      render :new
    end
  end

  # Смена workflow-статуса (в работу / выполнен / не выполнен) ИЛИ ручная
  # пометка покупки неподтверждённой — обе через одну кнопку-ссылку remote:true.
  # find_record авторизует через update_status? (action_name → предикат policy).
  def update_status
    @client_request = find_record ClientRequest

    if @client_request.update(status_params)
      respond_to do |format|
        format.js   # перерисовывает строку #client_request_<id>
        format.html { redirect_to client_requests_path, notice: t('.updated') }
      end
    else
      head :unprocessable_entity
    end
  end

  # История изменений (иконка часов) — читает HistoryRecord, как в clients#history.
  def history
    @client_request = find_record ClientRequest
    @records = @client_request.history_records.order(created_at: :desc)
    render 'shared/show_history'
  end

  private

  def client_request_params
    params.require(:client_request).permit(:client_id, :item_id, :reason)
  end

  # Разрешаем менять только эти два enum-поля. Кнопки шлют ровно одно из них.
  def status_params
    params.require(:client_request).permit(:status, :purchase_check_status)
  end
end
