class ElqueueTicketsReport < BaseReport
  attr_accessor :start_time
  attr_reader :start_date, :end_date, :end_time

  params %i[start_date end_date department_id start_end_time]

  def start_date=(value)
    @start_date = Date.parse(value).strftime('%d.%m.%Y')
  end

  def end_date=(value)
    @end_date = Date.parse(value).strftime('%d.%m.%Y')
  end

  def end_time=(value)
    @end_time = value.blank? ? '23:59' : value
  end

  def period
    Time.zone.parse("#{start_date} #{start_time}")..Time.zone.parse("#{end_date} #{end_time}")
  end

  def call
    @result = { name: 'Талоны в очереди', data: waiting_clients, resume: resume }
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
                                   .order('waiting_clients.ticket_issued_at ASC')

    waiting_clients.map do |wc|
      time_waited = wc.ticket_called_at ? (wc.ticket_called_at - wc.ticket_issued_at).div(60) : ''
      time_served = wc.ticket_served_at ? (wc.ticket_served_at - wc.ticket_called_at).div(60) : ''
      {
        elqueue_name: wc.electronic_queue.queue_name,
        ticket_number: wc.ticket_number,
        ticket_issued_at: wc.ticket_issued_at.strftime('%d.%m.%Y %H:%M'),
        ticket_called_at: wc.ticket_called_at&.strftime('%d.%m.%Y %H:%M') || '',
        ticket_time_waited: time_waited,
        ticket_served_at: wc.ticket_served_at&.strftime('%d.%m.%Y %H:%M') || '',
        ticket_time_served: time_served,
        queue_name: wc.queue_item_ancestors,
        status: wc.status.start_with?('completed') ? 'Завершён' : 'Не пришёл'
      }
    end
  end

  def resume
    result = {}
    waiting_clients = WaitingClient.unscoped
                                   .where(status: ['completed', 'did_not_come'])
                                   .where(ticket_issued_at: period)
                                   .joins(queue_item: { electronic_queue: :department })
                                   .where(queue_items:
                                            { electronic_queues:
                                                { departments: { id: department_id } } })
    result[:total] = waiting_clients.count(:ticket_number)

    queue_items_ary = waiting_clients.group('queue_items.id').select('queue_items.id').map do |queue_item_id|
      item = QueueItem.find(queue_item_id.id)
      [queue_item_id.id, item.ancestors_and_self_titles, item.ticket_abbreviation]
    end

    queue_items_total = []
    queue_items_average = []
    queue_items_ary.each do |items|
      wcs_for_item = waiting_clients.where(queue_item_id: items[0])
      queue_items_total << "#{items[2]} - #{items[1]} - #{wcs_for_item.size}"
      wcs_with_served = wcs_for_item.select(&:ticket_served_at)
      served_durations = wcs_with_served.map { |wc| (wc.ticket_served_at - wc.ticket_called_at).div(60) }
      average_served_time = served_durations.sum / served_durations.size.to_f
      queue_items_average << "#{items[2]} - #{items[1]} - #{average_served_time.round(2)}"
    end

    queue_items_total = queue_items_total.sort_by { |str| -str[/\d+\z/].to_i }.map { |str| str << ' шт.' }.join("\n")
    result[:queue_items_total] = queue_items_total

    queue_items_average = queue_items_average.sort_by { |str| -str[/\d+(?:.\d+)?\z/].to_f }.map { |str| str << ' мин.' }.join("\n")
    result[:avg_served_time] = queue_items_average

    filtered_with_called = waiting_clients.select(&:ticket_called_at)
    waiting_durations = filtered_with_called.map { |wc| (wc.ticket_called_at - wc.ticket_issued_at).div(60) }
    average_waiting_time = waiting_durations.sum / waiting_durations.size.to_f

    result[:avg_waiting_time] = average_waiting_time.round(2)
    result
  end
end
