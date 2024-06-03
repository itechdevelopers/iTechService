class ElectronicQueuesController < ApplicationController
  layout "application"
  before_action :set_and_authorize_record, only: [:show, :edit, :update, :destroy, :show_active_tickets]

  def ipad_show
    authorize ElectronicQueue
    @electronic_queue = ElectronicQueue.find_by(ipad_link: params[:permalink])
    @queue_items = @electronic_queue.queue_items.roots.order(position: :asc)
    render layout: "electronic_queues"
  end

  def tv_show
    authorize ElectronicQueue
    @electronic_queue = ElectronicQueue.find_by(tv_link: params[:permalink])
    @clients_in_service = WaitingClient.in_queue(@electronic_queue).in_service
    render layout: "electronic_queues"
  end

  def show_active_tickets
    @waiting_clients_in_service = WaitingClient.in_queue(@electronic_queue).in_service
    @waiting_clients_in_waiting = WaitingClient.in_queue(@electronic_queue).waiting
    respond_to do |format|
      format.js
    end
  end

  def index
    authorize ElectronicQueue
    @electronic_queues = ElectronicQueue.all
  end

  def show
    @queue_items = @electronic_queue.queue_items.roots.order(position: :asc)
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
      render 'form'
    end
  end

  def edit
    render 'form'
  end

  def update
    if @electronic_queue.update(electronic_queue_params)
      redirect_to electronic_queue_path(@electronic_queue), notice: t('.electronic_queue_was_successfully_updated')
    else
      render 'form'
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
      :printer_address, :ipad_link, :tv_link, :enabled, :check_info,
      :header_boldness, :annotation_boldness, :header_font_size, :annotation_font_size)
  end
end