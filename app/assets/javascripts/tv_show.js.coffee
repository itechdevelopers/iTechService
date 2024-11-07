$ ->
  window.waitingTicketsDisplay = null
  electronicQueueId = $('#electronic_queue_id').val()
  App.cable.subscriptions.create { channel: 'ElectronicQueueChannel', id: electronicQueueId },
    received: (data) ->
      if data['action'] == 'start_service'
        @startService(data['waiting_client'].ticket_number, data['window'])
      if data['action'] == 'complete_service'
        @completeService(data['waiting_client'].ticket_number)
      if data['action'] == 'add_to_queue'
        @addToQueue(data['waiting_client'].ticket_number)

    addToQueue: (ticketNumber) ->
      window.waitingTicketsDisplay?.addTicket(ticketNumber)

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
      $card.fadeIn(500).fadeOut(500).fadeIn(500).fadeOut(500).fadeIn(500, ->
        $card.show()
        window.waitingTicketsDisplay?.removeTicket(ticketNumber)
      )

    completeService: (ticketNumber) ->
      $('.elqueue-tv-card').each (index, element) ->
        if $(element).data('ticket-number') == ticketNumber
          $(element).fadeOut(1000, ->
            $(element).remove()
          )
          return false

#  Показ ожидающих талонов
  class WaitingTicketsDisplay
    constructor: ->
      @waitingTickets = JSON.parse($('#waiting_tickets').val() || '[]')
      @currentPage = 0
      @ticketsPerPage = 4
      @container = $('.elqueue-tv-waiting__tickets')
      @intervalTime = 5000
      @animationDuration = 1000

      @initDisplay() if @waitingTickets.length > 0

    addTicket: (ticketNumber) ->
      @waitingTickets.push(ticketNumber)
      @refreshDisplay()

    removeTicket: (ticketNumber) ->
      index = @waitingTickets.indexOf(ticketNumber)
      if index > -1
        @waitingTickets.splice(index, 1)

        totalPages = @getTotalPages()
        if totalPages > 0 && @currentPage >= totalPages
          @currentPage = totalPages - 1

        @refreshDisplay()

    refreshDisplay: ->
      clearInterval(@rotationInterval) if @rotationInterval?

      if @waitingTickets.length > 0
        @initDisplay()
      else
        @container.empty()

    initDisplay: ->
      @displayCurrentPage()
      @startRotation() if @waitingTickets.length > @ticketsPerPage

    displayCurrentPage: ->
      startIdx = @currentPage * @ticketsPerPage
      endIdx = startIdx + @ticketsPerPage
      currentTickets = @waitingTickets.slice(startIdx, endIdx)

      @fadeOutCurrentTickets().then =>
        html = @buildTicketsHtml(currentTickets)
        @container.html(html)

    fadeOutCurrentTickets: ->
      new Promise (resolve) =>
        if @container.children().length == 0
          resolve()
          return

        @container.children().addClass('fade-out')
        setTimeout(resolve, @animationDuration)

    buildTicketsHtml: (tickets) ->
      html = []
      for ticket, index in tickets
        html.push """
          <div class="elqueue-tv-waiting__ticket">
            #{ticket}
          </div>
        """
      html.join('')

    startRotation: ->
      @rotationInterval = setInterval =>
        @currentPage = (@currentPage + 1) % @getTotalPages()
        @displayCurrentPage()
      , @intervalTime

    getTotalPages: ->
      Math.ceil(@waitingTickets.length / @ticketsPerPage)

  $(document).ready ->
    window.waitingTicketsDisplay = new WaitingTicketsDisplay()