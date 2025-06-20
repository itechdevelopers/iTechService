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

  def morning_period
    Time.zone.parse("#{start_date} 10:00")..Time.zone.parse("#{start_date} 12:00")
  end

  def daytime_period
    Time.zone.parse("#{start_date} 12:00")..Time.zone.parse("#{start_date} 18:00")
  end

  def evening_period
    Time.zone.parse("#{start_date} 18:00")..Time.zone.parse("#{start_date} 20:00")
  end

  def call
    @result = { name: 'Талоны в очереди', data: waiting_clients(period), resume: resume(period) }
    @result[:pause_data] = pause_data(period)
    @result[:morning_time] = { data: waiting_clients(morning_period), resume: resume(morning_period) }
    @result[:morning_time][:pause_data] = pause_data(morning_period)
    @result[:day_time] = { data: waiting_clients(daytime_period), resume: resume(daytime_period) }
    @result[:day_time][:pause_data] = pause_data(daytime_period)
    @result[:evening_time] = { data: waiting_clients(evening_period), resume: resume(evening_period) }
    @result[:evening_time][:pause_data] = pause_data(evening_period)
  end

  private

  def pause_data(period)
    user_pauses = UserPause.joins(:user)
                           .where(users: { department_id: department.id })
                           .where('user_pauses.paused_at <= ? AND (user_pauses.resumed_at >= ? OR user_pauses.resumed_at IS NULL)', period.end, period.begin)
                           .order('users.username ASC, user_pauses.paused_at ASC')

    pauses_by_user = user_pauses.group_by(&:user)

    user_metrics = pauses_by_user.map do |user, pauses|
      total_duration = pauses.sum do |p|
        start_time = [p.paused_at, period.begin].max
        end_time = p.resumed_at.nil? ? period.end : [p.resumed_at, period.end].min
        duration = end_time - start_time
        duration.positive? ? duration : 0
      end

      {
        user_name: user.short_name,
        pause_count: pauses.count,
        total_duration_minutes: (total_duration / 60).round(2),
        pauses: pauses.map do |p|
          {
            paused_at: p.paused_at.in_time_zone(user.time_zone || 'UTC').strftime('%d.%m %H:%M'),
            resumed_at: p.resumed_at ? p.resumed_at.in_time_zone(user.time_zone || 'UTC').strftime('%d.%m %H:%M') : 'активна'
          }
        end
      }
    end

    by_count = user_metrics.sort_by { |h| -h[:pause_count] }
    by_duration = user_metrics.sort_by { |h| -h[:total_duration_minutes] }

    { by_count: by_count, by_duration: by_duration }
  end

  def waiting_clients(period)
    result = {}
    short_working_time = []
    electronic_queue = ElectronicQueue.where(department_id: department.id).last
    waiting_clients = WaitingClient.where(status: ['completed', 'did_not_come'])
                                   .where(ticket_issued_at: period)
                                   .joins(queue_item: :electronic_queue)
                                   .where(queue_items:
                                            { electronic_queue: electronic_queue })
                                   .order('waiting_clients.ticket_issued_at ASC')

    window_user_pairs = []

    result[:waiting_clients] = waiting_clients.map do |wc|
      time_waited = wc.ticket_called_at ? (wc.ticket_called_at - wc.ticket_issued_at).div(60) : ''
      time_served = wc.ticket_served_at ? (wc.ticket_served_at - wc.ticket_called_at).div(60) : ''
      missing_ticket = !wc.status.start_with?('completed')
      completed_automatically = wc.completed_automatically
      called_event = wc.elqueue_ticket_movements.where(type: "ElqueueTicketMovement::Called").order(created_at: :desc).first
      username = called_event&.user&.short_name || '-'
      called_at = called_event&.created_at.strftime('%d.%m.%Y %H:%M')

      window = called_event&.elqueue_window
      calling_user = called_event&.user

      if called_event
        window_user_pairs << {
          window: window.window_number,
          user: calling_user
        }
      end

      if !missing_ticket && time_served <= 3
        short_working_time << { number: wc.ticket_number, time: time_served, user: username, called_at: called_at }
      end

      status = if completed_automatically
                 missing_ticket ? 'Не пришёл (завершено автоматически)' : 'Завершено (завершено автоматически)'
               else
                 missing_ticket ? 'Не пришёл' : 'Завершено'
               end

      {
        ticket_number: wc.ticket_number,
        ticket_issued_at: wc.ticket_issued_at.strftime('%d.%m.%Y %H:%M'),
        ticket_called_at: wc.ticket_called_at&.strftime('%d.%m.%Y %H:%M') || '',
        ticket_time_waited: time_waited,
        ticket_served_at: wc.ticket_served_at&.strftime('%d.%m.%Y %H:%M') || '',
        ticket_time_served: missing_ticket ? '-' : time_served,
        queue_name: wc.queue_item_ancestors,
        status: status,
        user_called: username
      }
    end

    window_user_pairs = window_user_pairs.uniq { |pair| [pair[:window], pair[:user].id] }
    result[:window_user_pairs] = format_window_user_summary(window_user_pairs)

    result[:short_working_time] = short_working_time.map { |elem| "#{elem[:called_at]} #{elem[:number]} - #{elem[:user]} #{elem[:time]} мин." }
                                                    .join("\n")
    result
  end

  def resume(period)
    result = {}
    electronic_queue = ElectronicQueue.where(department_id: department.id).last
    result[:elqueue_name] = electronic_queue.queue_name

    waiting_clients = WaitingClient.unscoped
                                   .where(status: ['completed', 'did_not_come'])
                                   .where(ticket_issued_at: period)
                                   .joins(queue_item: :electronic_queue)
                                   .where(queue_items:
                                            { electronic_queue: electronic_queue })

    # Сводка по всем клиентам и клиентам, которые не пришли
    result[:total] = "Всего клиентов: #{waiting_clients.count(:ticket_number)}\n"
    missing_clients = waiting_clients.where(status: ['did_not_come'])
    result[:total] << "Не пришло #{missing_clients.size} клиентов.\n\n"
    waiting_times = []
    missing_clients.each do |wc|
      waiting_time = (wc.ticket_called_at - wc.ticket_issued_at).div(60)
      result[:total] << "#{wc.ticket_number} - #{waiting_time} минут \n"
      waiting_times << waiting_time
    end
    average_waiting_time_missing = average_time(waiting_times).round(2)
    result[:total] << "Среднее время ожидания для клиентов, которые не пришли: #{average_waiting_time_missing} минут."

    # Подсчет среднего и медианного времени выполнения и количества клиентов по пунктам электронной очереди
    queue_items_ary = waiting_clients.group('queue_items.id').select('queue_items.id').map do |queue_item_id|
      item = QueueItem.find(queue_item_id.id)
      [queue_item_id.id, item.ancestors_and_self_titles, item.ticket_abbreviation]
    end

    queue_items_total = []
    queue_items_average = []
    queue_items_median = []
    long_queue_items_median = []
    long_queue_items_average = []

    queue_items_ary.each do |items|
      wcs_for_item = waiting_clients.where(queue_item_id: items[0])
      queue_items_total << "#{items[2]} - #{items[1]} - #{wcs_for_item.size}"
      wcs_with_served = wcs_for_item.where(status: 'completed').select(&:ticket_served_at)

      served_durations = wcs_with_served.map { |wc| (wc.ticket_served_at - wc.ticket_called_at).div(60) }
      long_served_durations = served_durations.select { |duration| duration > 3 }

      queue_items_median << "#{items[2]} - #{items[1]} - #{median_time(served_durations).round(2)}"
      queue_items_average << "#{items[2]} - #{items[1]} - #{average_time(served_durations).round(2)}"
      long_queue_items_median << "#{items[2]} - #{items[1]} - #{median_time(long_served_durations).round(2)}"
      long_queue_items_average << "#{items[2]} - #{items[1]} - #{average_time(long_served_durations).round(2)}"
    end

    queue_items_total = queue_items_total.sort_by { |str| -str[/\d+\z/].to_i }.map { |str| str << ' шт.' }.join("\n")
    result[:queue_items_total] = queue_items_total

    queue_items_average = queue_items_average.sort_by { |str| -str[/\d+(?:.\d+)?\z/].to_f }.map { |str| str << ' мин.' }.join("\n")
    result[:avg_served_time] = queue_items_average

    queue_items_median = queue_items_median.sort_by { |str| -str[/\d+(?:.\d+)?\z/].to_f }.map { |str| str << ' мин.' }.join("\n")
    result[:median_served_time] = queue_items_median

    long_queue_items_average = long_queue_items_average.sort_by { |str| -str[/\d+(?:.\d+)?\z/].to_f }.map { |str| str << ' мин.' }.join("\n")
    result[:long_avg_served_time] = long_queue_items_average

    long_queue_items_median = long_queue_items_median.sort_by { |str| -str[/\d+(?:.\d+)?\z/].to_f }.map { |str| str << ' мин.' }.join("\n")
    result[:long_median_served_time] = long_queue_items_median

    # Среднее время ожидания всех задач
    filtered_with_called = waiting_clients.select(&:ticket_called_at)
    waiting_durations = filtered_with_called.map { |wc| (wc.ticket_called_at - wc.ticket_issued_at).div(60) }
    average_waiting_time = waiting_durations.sum / waiting_durations.size.to_f
    median_waiting_time = median_time(waiting_durations).round(2)
    result[:avg_waiting_time] = average_waiting_time.round(2)
    result[:median_waiting_time] = median_waiting_time

    result
  end

  def format_window_user_summary(pairs)
    return "Нет данных о работе окон" if pairs.empty?
    
    window_groups = pairs.group_by { |pair| pair[:window] }
    unique_windows_count = window_groups.keys.size

    result = "Всего работало окон: #{unique_windows_count}\n"
    
    window_groups.each do |_window_id, window_data|
      window = window_data.first[:window]
      users = window_data.map { |pair| pair[:user] }.uniq
      
      result << "Окно №#{window}:\n"
      users.each do |user|
        result << "  - #{user.short_name}\n"
      end
      result << "\n"
    end
    
    result
  end

  def median_time(durations)
    sorted = durations.sort
    size = sorted.size

    return 0 if size.zero?

    if size.odd?
      sorted[size / 2]
    else
      (sorted[(size - 1) / 2] + sorted[size / 2]) / 2.0
    end
  end

  def average_time(durations)
    size = durations.size
    return 0 if size.zero?

    durations.sum / size.to_f
  end
end
