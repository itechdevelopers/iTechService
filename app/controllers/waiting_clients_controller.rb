class WaitingClientsController < ApplicationController
  before_action :set_waiting_client, only: %i[complete show assign_window reassign_window]

  def create
    authorize WaitingClient
    @waiting_client = WaitingClient.new(waiting_client_params)

    if @waiting_client.phone_number.present?
      normalized_phone = PhonyRails.normalize_number(@waiting_client.phone_number,
                                                     country_code: @waiting_client.country_code)
      @waiting_client.phone_number = normalized_phone
    end
    @waiting_client.save!

    respond_to do |format|
      if @waiting_client.valid?
        @waiting_client.elqueue_ticket_movements.create(type: 'ElqueueTicketMovement::NewTicket',
                                                        priority: @waiting_client.priority_value,
                                                        new_position: @waiting_client.position,
                                                        electronic_queue: @waiting_client.electronic_queue,
                                                        queue_state: @waiting_client.electronic_queue.queue_state)
        print_pdf
        format.json { render json: { ticket_number: @waiting_client.ticket_number } }
      else
        format.json { render json: @waiting_client.errors, status: :unprocessable_entity }
      end
    end
  end

  def complete
    authorize @waiting_client
    did_not_come = params[:did_not_come].present? ? true : false
    @waiting_client.complete_service(did_not_come)
    current_user.unset_remember_pause if current_user.waiting_for_break?
  end

  def show
    authorize @waiting_client
    respond_to do |format|
      format.pdf do
        print_pdf
        send_data @pdf.render, filename: @pdf_filename, type: "application/pdf", disposition: "inline"
      end
    end
  end

  def assign_window
    authorize @waiting_client
    respond_to do |format|
      if @waiting_client.assign_window(waiting_client_params[:attached_window].to_i)
        format.js
      else
        format.js { head :unprocessable_entity }
      end
    end
  end

  def reassign_window
    authorize @waiting_client
    @waiting_client.reassign_window(waiting_client_params[:attached_window].to_i, current_user)
    respond_to(&:js)
  end

  private

  def waiting_client_params
    params.require(:waiting_client).permit(:queue_item_id, :client_name, :phone_number, :country_code,
                                           :attached_window)
  end

  def set_waiting_client
    @waiting_client = WaitingClient.find(params[:id])
  end

  def print_pdf
    @pdf = WaitingClientPdf.new @waiting_client, view_context
    @pdf_filename = "ticket_#{@waiting_client.ticket_number}.pdf"
    filepath = "#{Rails.root}/tmp/pdf/#{@pdf_filename}"
    @pdf.render_file filepath
    printer = @waiting_client.electronic_queue.printer_address
    PrinterTools.print_file filepath,
                            type: :waiting_client,
                            height: @pdf.page_height_mm,
                            printer: printer
  end
end
