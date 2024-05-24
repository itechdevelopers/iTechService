class ElectronicQueueChannel < ApplicationCable::Channel
  def subscribed
    electronic_queue = ElectronicQueue.find(params[:id])
    stream_for electronic_queue
  end
end