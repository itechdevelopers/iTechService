class ElectronicQueuesController < ApplicationController
  layout 'application'
  skip_before_action :authenticate_user!, only: %i[ipad_show tv_show]
  before_action :custom_authenticate_user, only: %i[ipad_show tv_show]
  before_action :set_and_authorize_record, only: %i[show edit update destroy show_active_tickets
                                                    manage_tickets sort_tickets return_old_ticket
                                                    manage_windows monitoring]

  def ipad_show
    authorize ElectronicQueue
    @electronic_queue = ElectronicQueue.find_by(ipad_link: params[:permalink])
    @queue_items = @electronic_queue.queue_items.not_archived.roots.order(position: :asc)
    render layout: 'electronic_queues'
  end

  def tv_show
    authorize ElectronicQueue
    @electronic_queue = ElectronicQueue.find_by(tv_link: params[:permalink])
    @clients_in_service = WaitingClient.in_queue(@electronic_queue).in_service
    render layout: 'electronic_queues'
  end

  def show_active_tickets
    @waiting_clients_in_service = WaitingClient.in_queue(@electronic_queue).in_service
    @waiting_clients_in_waiting = WaitingClient.in_queue(@electronic_queue).waiting
    respond_to(&:js)
  end

  def manage_tickets
    @modal = 'manage_tickets'
    @waiting_clients = WaitingClient.in_queue(@electronic_queue).waiting
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def manage_windows
    @modal = 'manage_windows'
    @elqueue_windows = @electronic_queue.elqueue_windows
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def return_old_ticket
    @modal = 'manage_tickets'
    @waiting_clients = WaitingClient.in_queue(@electronic_queue).waiting
    @waiting_client = WaitingClient.find(params[:ticket_id].to_i)
    @waiting_client.return_to_queue(current_user)
  end

  def monitoring

  end

  def index
    authorize ElectronicQueue
    @electronic_queues = ElectronicQueue.all
  end

  def show
    @queue_items = @electronic_queue.queue_items.not_archived.roots.order(position: :asc)
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

  def sort_tickets
    sorted_tickets = JSON.parse(electronic_queue_params[:ticket_ids])
    moved_ticket_id = electronic_queue_params[:id_moved]
    wc = WaitingClient.find(moved_ticket_id)
    old_pos = wc.position
    ActiveRecord::Base.transaction do
      sorted_tickets.each do |ticket|
        WaitingClient.find(ticket['id'])
                     .update(position: ticket['position'])
      end
      wc.reload
      new_pos = wc.position
      wc.elqueue_ticket_movements.create(type: 'ElqueueTicketMovement::Manual',
                                         user: current_user,
                                         old_position: old_pos,
                                         new_position: new_pos,
                                         electronic_queue: @electronic_queue,
                                         queue_state: @electronic_queue.queue_state)
    end
    respond_to do |format|
      format.js { head :ok }
    end
  end

  private

  def custom_authenticate_user
    unless user_signed_in?
      session[:user_return_to] = request.fullpath
      redirect_to user_new_technical_login_path
    end
  end

  def set_and_authorize_record
    @electronic_queue = authorize ElectronicQueue.find(params[:id])
  end

  def electronic_queue_params
    params.require(:electronic_queue).permit(:queue_name, :department_id, :windows_count,
                                             :printer_address, :ipad_link, :tv_link, :enabled, :check_info,
                                             :header_boldness, :annotation_boldness, :header_font_size,
                                             :annotation_font_size, :ticket_ids, :background_color, :queue_item_color,
                                             :back_button_color, :id_moved)
  end
end