jQuery ->
  $(document).on 'click', '.dot-movement', (event) ->
    detailedInfo = $('#detailed-ticket-info')
    if detailedInfo.length
      detailedInfo.remove()
      return

    ticketId = $(this).data('ticket-id')
    detailedInfo = $('<div>').attr('id', 'detailed-ticket-info')
    detailedInfo.css('top', '180px')
    detailedInfo.css('left', '12px')
    $(this).append(detailedInfo)
    $.getScript("/elqueue_ticket_movements/detailed_ticket_info?waiting_client_id=#{ticketId}")

