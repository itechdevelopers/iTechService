module ElqueueTicketMovementsHelper
  PRIORITIES = {
    '1': 'Всегда первый',
    '2': 'Второй',
    '3': 'Третий'
  }.freeze
  def ticket_boosts_str(ticket, movements)
    ticket_movements = movements.select { |m| m.waiting_client_id == ticket.id }

    result = ''
    move_created = ticket_movements.find { |m| m.type == 'ElqueueTicketMovement::NewTicket' }
    result << 'priority_boost' if [1, 2, 3].include?(move_created&.priority)
    result << 'timeout_boost' if ticket_movements.any? { |m| m.type == 'ElqueueTicketMovement::TimeoutMoved' }
    result << 'manual_boost' if ticket_movements.any? { |m| m.type == 'ElqueueTicketMovement::Manual' }
    result
  end

  def dot_color_str(ticket, movements)
    if movements.any? { |m| m.waiting_client_id == ticket.id && m.type == 'ElqueueTicketMovement::RequeuedCompleted' }
      'pink'
    elsif ticket.status == 'did_not_come'
      'red'
    else
      ''
    end
  end

  def user_served_str(ticket_movements)
    called_events = ticket_movements.select { |m| m.type == 'ElqueueTicketMovement::Called' }
    latest_element = called_events.max_by(&:created_at)
    user_id = latest_element&.user_id
    if user_id
      User.find(user_id).short_name
    else
      'Отсутствует'
    end
  end

  def user_requeued_completed_str(ticket_movements)
    requeued_events = ticket_movements.select { |m| m.type == 'ElqueueTicketMovement::RequeuedCompleted' }
    latest_element = requeued_events.max_by(&:created_at)
    user_id = latest_element&.user_id
    if user_id
      User.find(user_id).short_name
    else
      'Отсутствует'
    end
  end

  def manual_boost_str(ticket_movements)
    boost_events = ticket_movements.select { |m| m.type == 'ElqueueTicketMovement::Manual' }
    latest_element = boost_events.max_by(&:created_at)
    user_id = latest_element&.user_id
    if user_id
      "#{User.find(user_id).short_name}, с позиции #{latest_element.old_position} на #{latest_element.new_position}"
    else
      'Отсутствует'
    end
  end

  def timeout_boost_str(ticket_movements)
    timeout_events = ticket_movements.select { |m| m.type == 'ElqueueTicketMovement::TimeoutMoved' }
    latest_element = timeout_events.max_by(&:created_at)
    if latest_element
      "C позиции #{latest_element.old_position} на #{latest_element.new_position}"
    else
      'Отсутствует'
    end
  end

  def priority_boost_str(ticket_movements)
    priority_events = ticket_movements.select { |m| m.type == 'ElqueueTicketMovement::NewTicket' }
    latest_element = priority_events.max_by(&:created_at)
    if latest_element && [1, 2, 3].include?(latest_element.priority)
      priority = PRIORITIES[latest_element.priority.to_s.intern]
      "приоритет - #{priority}, талон добавлен на позицию #{latest_element.new_position}"
    else
      'Отсутствует'
    end
  end

  def ticket_archived_at(ticket_movements)
    archived_events = ticket_movements.select { |m| m.type == 'ElqueueTicketMovement::Archived' }
    latest_element = archived_events.max_by(&:created_at)
    return '' unless latest_element

    latest_element.created_at.strftime('%H:%M:%S')
  end
end
