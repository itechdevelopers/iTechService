class WaitingClientsController < ApplicationController
  before_action :set_waiting_client, only: %i[complete]

  def create
    authorize WaitingClient
    @waiting_client = WaitingClient.new(waiting_client_params)
    @waiting_client.save
    redirect_to ipad_show_path(permalink: @waiting_client.queue_item.electronic_queue.ipad_link)
  end

  def complete
    authorize @waiting_client
    did_not_come = params[:did_not_come].present? ? true : false
    @waiting_client.complete_service(did_not_come)
  end

  private

  def waiting_client_params
    params.require(:waiting_client).permit(:queue_item_id, :client_name, :phone_number)
  end

  def set_waiting_client
    @waiting_client = WaitingClient.find(params[:id])
  end
end