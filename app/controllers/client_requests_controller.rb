# frozen_string_literal: true

class ClientRequestsController < ApplicationController
  def index
    authorize ClientRequest
    @client_requests = ClientRequest.recent
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

  private

  def client_request_params
    params.require(:client_request).permit(:client_id, :item_id, :reason)
  end
end
