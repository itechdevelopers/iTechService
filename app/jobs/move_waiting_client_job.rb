class MoveWaitingClientJob < ApplicationJob
  queue_as :default

  def perform(waiting_client_id)
    waiting_client = WaitingClient.find(waiting_client_id)
    waiting_client.move_to_beginning if waiting_client.status == "waiting"
  end
end
