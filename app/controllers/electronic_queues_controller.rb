class ElectronicQueuesController < ApplicationController
  before_action :set_and_authorize_record, only: [:show, :edit, :update, :destroy]

  def index
    authorize ElectronicQueue
    @electronic_queues = ElectronicQueue.all
  end

  def show
    @queue_items = @electronic_queue.queue_items.order(position: :asc)
  end

  def new
    @electronic_queue = authorize ElectronicQueue.new
    render 'form'
  end

  def create
    @electronic_queue = authorize ElectronicQueue.new(electronic_queue_params)
    if @electronic_queue.save
      redirect_to electronic_queue_path(@electronic_queue), notice: t('.electronic_queue_was_successfully_created')
    else
      render :new
    end
  end

  def edit
    render 'form'
  end

  def update
    if @electronic_queue.update(electronic_queue_params)
      redirect_to electronic_queue_path(@electronic_queue), notice: t('.electronic_queue_was_successfully_updated')
    else
      render :edit
    end
  end

  def destroy
    @electronic_queue.destroy
    redirect_to electronic_queues_path, notice: t('.electronic_queue_was_successfully_deleted')
  end

  private

  def set_and_authorize_record
    @electronic_queue = authorize ElectronicQueue.find(params[:id])
  end

  def electronic_queue_params
    params.require(:electronic_queue).permit(:queue_name, :department_id, :windows_count,
      :printer_address, :ipad_link, :tv_link, :enabled)
  end
end