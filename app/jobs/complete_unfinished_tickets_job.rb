class CompleteUnfinishedTicketsJob < ApplicationJob
  queue_as :default

  def perform(elqueue_id)
    electronic_queue = ElectronicQueue.find(elqueue_id)
    tickets_in_service = WaitingClient.in_queue(electronic_queue).in_service
    tickets_in_service.each(&:complete_automatically)
    tickets_waiting = WaitingClient.in_queue(electronic_queue).waiting
    tickets_waiting.each(&:complete_waiting_automatically)
  end
end
