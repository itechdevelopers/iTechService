class QueueItemsController < ApplicationController
  before_action :params_to_valid_hash, only: %i[create update]
  before_action :set_electronic_queue, only: %i[new create edit update destroy]

  def new
    @queue_item = authorize @electronic_queue.queue_items.new(new_queue_item_params)
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

  def edit
    @queue_item = authorize @electronic_queue.queue_items.find(params[:id])
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def update
    @queue_item = authorize @electronic_queue.queue_items.find(params[:id])
    @queue_items = @electronic_queue.queue_items.roots.order(position: :asc)
    respond_to do |format|
      if @queue_item.update(queue_item_params)
        format.js
      else
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    @queue_item = authorize @electronic_queue.queue_items.find(params[:id])
    @queue_item.update(archived: true)
    respond_to(&:js)
  end

  def unarchive
    @queue_item = find_record QueueItem
    if @queue_item.update(archived: false)
      redirect_to @queue_item.electronic_queue, notice: 'Элемент очереди успешно разархивирован.'
    else
      redirect_to @queue_item.electronic_queue, alert: 'Не удалось разархивировать элемент очереди.'
    end
  end

  private

  def new_queue_item_params
    return {} unless params[:queue_item]
    params.require(:queue_item).permit(:parent_id)
  end

  def queue_item_params
    params.require(:queue_item).permit(:title, :annotation, :phone_input,
      :windows, :task_duration, :max_wait_time, :additional_info, :ticket_abbreviation,
      :position, :electronic_queue_id, :ancestry, :ancestry_depth, :parent_id,
      :priority)
  end

  def params_to_valid_hash
    params[:queue_item][:priority] = params[:queue_item][:priority].to_i if params[:queue_item][:priority]
  end

  def set_electronic_queue
    @electronic_queue = authorize ElectronicQueue.find(params[:electronic_queue_id])
  end
end