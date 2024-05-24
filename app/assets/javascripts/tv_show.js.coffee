$ ->
  electronicQueueId = $('#electronic_queue_id').val()
  App.cable.subscriptions.create { channel: 'ElectronicQueueChannel', id: electronicQueueId },
    received: (data) ->
      if data['action'] == 'start_service'
        @startService(data['waiting_client'].ticket_number, data['window'])
      if data['action'] == 'complete_service'
        @completeService(data['waiting_client'].ticket_number)

    startService: (ticketNumber, window) ->
      $tr = $('<tr>').addClass('tv-elqueue-clients-table-row')
      $tdTicketNumber = $('<td>').text(ticketNumber)
      $tdArrow = $('<td>').html('&#x279C;')
      $tdWindowNumber = $('<td>').text(window)

      $tr.append($tdTicketNumber)
      $tr.append($tdArrow)
      $tr.append($tdWindowNumber)

      $('.tv-elqueue-clients-table tbody').append($tr)

      $tr.fadeIn(1000).fadeOut(1000).fadeIn(1000).fadeOut(1000).fadeIn(1000, ->
        $tr.show()
      )

    completeService: (ticketNumber) ->
      $('.tv-elqueue-clients-table td').each (index, element) ->
        if $(element).text() == ticketNumber
          $(element).fadeOut(1000, ->
            $(element).closest('tr').remove()
          )
          return false