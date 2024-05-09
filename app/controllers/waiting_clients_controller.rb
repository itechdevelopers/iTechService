class WaitingClientsController < ApplicationController
  def create
    @waiting_client = WaitingClient.new(waiting_client_params)
    @waiting_client.save
    redirect_to ipad_show_path(permalink: @waiting_client.queue_item.electronic_queue.ipad_link)
  end

  private

  def waiting_client_params
    params.require(:waiting_client).permit(:queue_item_id, :client_name, :phone_number)
  end
end