$ ->
  electronicQueueId = $('#electronic_queue_id').val()
  App.cable.subscriptions.create { channel: 'ElectronicQueueChannel', id: electronicQueueId },
    received: (data) ->
      if data['action'] == 'start_service'
        @startService(data['waiting_client'].ticket_number, data['window'])
      if data['action'] == 'complete_service'
        @completeService(data['waiting_client'].ticket_number)

    startService: (ticketNumber, windowNumber) ->
      $card = $('<div>').addClass('elqueue-tv-card').data('ticket-number', ticketNumber)

      $ticketNumber = $('<span>').addClass('ticket-info').text(ticketNumber)
      $ticketNumber.append($('<span>').addClass('label-tv').text('Талон'))
      $arrow = $('<span>').addClass('arrow-tv').html('&#x279C;')
      $ticketWindow = $('<span>').addClass('ticket-info').text(windowNumber)
      $ticketWindow.append($('<span>').addClass('label-tv').text('Окно'))

      $card.append($ticketNumber)
      $card.append($arrow)
      $card.append($ticketWindow)

      $('.elqueue-tv').append($card)
      $card.fadeIn(1000).fadeOut(1000).fadeIn(1000).fadeOut(1000).fadeIn(1000, ->
        $card.show()
      )

    completeService: (ticketNumber) ->
      $('.elqueue-tv-card').each (index, element) ->
        if $(element).data('ticket-number') == ticketNumber
          $(element).fadeOut(1000, ->
            $(element).remove()
          )
          return false