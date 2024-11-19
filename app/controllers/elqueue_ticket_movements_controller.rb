class ElqueueTicketMovementsController < ApplicationController

  def filter_movements_by_called
    authorize ElqueueTicketMovement

    date_str = elqueue_ticket_movements_params[:date]
    time_str = elqueue_ticket_movements_params[:time]

    ids = ElqueueTicketMovement::Called.where(created_at: start_datetime(date_str, time_str)..end_datetime,
                                              electronic_queue_id: elqueue_ticket_movements_params[:electronic_queue_id])
                                       .pluck(:waiting_client_id)
    tickets = WaitingClient.where(id: ids).order(ticket_called_at: :asc)
    archived_tickets = WaitingClient.where(status: 'archived')
    @tickets = tickets + archived_tickets
    @movements = ElqueueTicketMovement.where(waiting_client: @tickets).select(:type, :priority, :waiting_client_id)

    respond_to(&:js)
  end

  def find_ticket_by_called
    authorize ElqueueTicketMovement

    date_s = elqueue_ticket_movements_params[:date].to_datetime.in_time_zone
    ticket_number = elqueue_ticket_movements_params[:ticket_number]
    electronic_queue_id = elqueue_ticket_movements_params[:electronic_queue_id]
    tickets = WaitingClient.joins(:queue_item)
                           .where(ticket_called_at: date_s.beginning_of_day..date_s.end_of_day,
                                  ticket_number: ticket_number,
                                  queue_items: { electronic_queue_id: electronic_queue_id })
    archived_tickets = WaitingClient.where(status: :archived, ticket_number: ticket_number)
    @tickets = tickets + archived_tickets
    @movements = ElqueueTicketMovement.where(waiting_client_id: @tickets).select(:type, :priority, :waiting_client_id)
    render 'filter_movements_by_called'
  end

  def detailed_ticket_info
    authorize ElqueueTicketMovement
    @ticket = WaitingClient.find(params[:waiting_client_id])
    @ticket_movements = @ticket.elqueue_ticket_movements

    respond_to(&:js)
  end

  private

  def start_datetime(date_str, time_str)
    @start_datetime ||= begin
      date = Date.strptime(date_str, '%d.%m.%Y')
      time = Time.new(date.year, date.month, date.day, time_str.to_i)
      time.to_datetime
    end
  end

  def end_datetime
    @end_datetime ||= @start_datetime + 1.hour
  end

  def elqueue_ticket_movements_params
    params.require(:elqueue_ticket_movement).permit(:date, :time, :electronic_queue_id, :ticket_number)
  end
end
