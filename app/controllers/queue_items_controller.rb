class QueueItemsController < ApplicationController
  before_action :set_electronic_queue, only: %i[new create]

  def new
    @queue_item = authorize @electronic_queue.queue_items.new
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def create
    @queue_item = authorize @electronic_queue.queue_items.new(queue_item_params)

    respond_to do |format|
      if @queue_item.save
        format.js
      else
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  private

  def queue_item_params
    params.require(:queue_item).permit(:title, :annotation, :phone_input,
      :windows, :task_duration, :max_wait_time, :additional_info, :ticket_abbreviation,
      :position, :electronic_queue_id)
  end

  def set_electronic_queue
    @electronic_queue = authorize ElectronicQueue.find(params[:electronic_queue_id])
  end
end