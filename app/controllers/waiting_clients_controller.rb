class WaitingClientsController < ApplicationController
  before_action :set_waiting_client, only: %i[complete show]

  def create
    authorize WaitingClient
    @waiting_client = WaitingClient.new(waiting_client_params)

    normilized_phone = PhonyRails.normalize_number(@waiting_client.phone_number, country_code: @waiting_client.country_code)
    @waiting_client.phone_number = normilized_phone

    @waiting_client.save
    print_pdf
    redirect_to ipad_show_path(permalink: @waiting_client.queue_item.electronic_queue.ipad_link)
  end

  def complete
    authorize @waiting_client
    did_not_come = params[:did_not_come].present? ? true : false
    @waiting_client.complete_service(did_not_come)
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

  private

  def waiting_client_params
    params.require(:waiting_client).permit(:queue_item_id, :client_name, :phone_number, :country_code)
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