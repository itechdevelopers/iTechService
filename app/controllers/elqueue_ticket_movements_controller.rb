class ElqueueTicketMovementsController < ApplicationController

  def filter_movements_by_called
    authorize ElqueueTicketMovement

    date_str = elqueue_ticket_movements_params[:date]
    time_str = elqueue_ticket_movements_params[:time]

    ids = ElqueueTicketMovement::Called.where(created_at: start_datetime(date_str, time_str)..end_datetime,
                                              electronic_queue_id: elqueue_ticket_movements_params[:electronic_queue_id])
                                       .pluck(:waiting_client_id)
    @tickets = WaitingClient.where(id: ids)
    @movements = ElqueueTicketMovement.where(waiting_client: @tickets).select(:type, :priority, :waiting_client_id)
    Rails.logger.info(ids)

    respond_to(&:js)
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
    params.require(:elqueue_ticket_movement).permit(:date, :time, :electronic_queue_id)
  end
end
