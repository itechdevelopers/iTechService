class ElqueueTicketsReport < BaseReport
  def call
    @result = { name: 'Талоны в очереди', data: waiting_clients }
  end

  private

  def waiting_clients
    department_id = department.id
    waiting_clients = WaitingClient.where(status: ['completed', 'did_not_come'])
                                   .where(ticket_issued_at: period)
                                   .joins(queue_item: { electronic_queue: :department })
                                   .where(queue_items:
                                            { electronic_queues:
                                               { departments: { id: department_id } } })
    waiting_clients.map do |wc|
      {
        elqueue_name: wc.electronic_queue.queue_name,
        ticket_number: wc.ticket_number,
        ticket_issued_at: wc.ticket_issued_at.strftime('%d.%m.%Y %H:%M'),
        ticket_called_at: wc.ticket_called_at&.strftime('%d.%m.%Y %H:%M') || '',
        ticket_served_at: wc.ticket_served_at&.strftime('%d.%m.%Y %H:%M') || '',
        queue_name: wc.queue_item_ancestors,
        status: wc.status.start_with?('completed') ? 'Завершён' : 'Не пришёл'
      }
    end
  end
end