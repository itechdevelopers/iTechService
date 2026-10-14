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
      if data['action'] == 'archive'
        @archive(data['waiting_client'].ticket_number)
      if data['action'] == 'repeat_audio'
        @repeatAudio(data['waiting_client'].ticket_number, data['window'])
      if data['action'] == 'window_pause'
        @windowPause(data['window_number'])
      if data['action'] == 'window_resume'
        @windowResume(data['window_number'])

    archive: (ticketNumber) ->
      window.waitingTicketsDisplay?.removeTicket(ticketNumber)

    addToQueue: (ticketNumber) ->
      window.waitingTicketsDisplay?.addTicket(ticketNumber)

    startService: (ticketNumber, windowNumber) ->
      $card = $('<div>').addClass('elqueue-tv-card').data('ticket-number', ticketNumber).data('window-number', windowNumber)

      $ticketNumber = window.createColorizedTicketNumber(ticketNumber)
      $ticketNumber.append($('<span>').addClass('label-tv').text(''))
      $arrow = $('<span>').addClass('arrow-tv').html('&#x279C;')
      $ticketWindow = $('<span>').addClass('ticket-info').text(windowNumber)
      $ticketWindow.append($('<span>').addClass('label-tv').text(''))

      $card.append($ticketNumber)
      $card.append($arrow)
      $card.append($ticketWindow)

      $('.elqueue-tv').append($card)
      window.audioPlayer?.playSound({ ticketNumber: ticketNumber, windowNumber: windowNumber })
      $card.fadeIn(500).fadeOut(500).fadeIn(500).fadeOut(500).fadeIn(500, ->
        $card.show()
        window.waitingTicketsDisplay?.removeTicket(ticketNumber)

        # Clean up any stale cards for this window after animation completes
        # We wait a bit to ensure any ongoing completeService animations finish
        setTimeout(->
          $('.elqueue-tv-card').each (index, element) ->
            $element = $(element)
            # Remove cards for same window but different ticket
            if $element.data('window-number') == windowNumber && $element.data('ticket-number') != ticketNumber
              $element.stop(true, true).fadeOut(500, ->
                $element.remove()
              )
        , 1000)  # Wait 1 second after animation to avoid conflicts
      )

    completeService: (ticketNumber) ->
      $('.elqueue-tv-card').each (index, element) ->
        if $(element).data('ticket-number') == ticketNumber
          # Stop any ongoing animations and immediately fade out
          $(element).stop(true, true).fadeOut(1000, ->
            $(element).remove()
          )
          return false

    repeatAudio: (ticketNumber, windowNumber) ->
      window.audioPlayer?.playSound({ ticketNumber: ticketNumber, windowNumber: windowNumber })

    windowPause: (windowNumber) ->
      $container = $('.elqueue-tv-paused__windows')
      exists = $container.find("[data-window-number='#{windowNumber}']").length > 0
      unless exists
        $span = $('<span>').addClass('elqueue-tv-paused__window-number')
          .attr('data-window-number', windowNumber)
          .text(windowNumber)
        $container.append($span)
        @sortPausedWindows()
      @togglePausedVisibility()

    windowResume: (windowNumber) ->
      $('.elqueue-tv-paused__windows').find("[data-window-number='#{windowNumber}']").remove()
      @togglePausedVisibility()

    sortPausedWindows: ->
      $container = $('.elqueue-tv-paused__windows')
      $spans = $container.children().sort (a, b) ->
        parseInt($(a).data('window-number')) - parseInt($(b).data('window-number'))
      $container.append($spans)

    togglePausedVisibility: ->
      $paused = $('.elqueue-tv-paused')
      if $('.elqueue-tv-paused__windows').children().length > 0
        $paused.show()
      else
        $paused.hide()

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

  class AudioPlayer

    constructor: ->
      # Загруженные записи со страницы «Озвучка», а где их нет — встроенные файлы
      @audioPaths = JSON.parse($('#audio_paths').val() || '{}')
      @audioBuffers = {}
      @audioContext = null
      @soundQueue = []
      @audioIsCurrentlyPlaying = false
      @setupInitializationButton()

    setupInitializationButton: ->
      $('.initialize-audio').on 'click', (e) =>
        e.preventDefault()
        @initializeAudio()
        $(e.target).parent().hide()

    initializeAudio: ->
      @audioContext = new AudioContext()
      @loadInitialSounds()

    loadInitialSounds: ->
      Object.keys(@audioPaths).forEach (soundName) =>
        @loadSound(soundName)

    # Преобразует номер талона в массив названий аудио-файлов
    getAudioPartsForTicket: (ticketNumber, windowNumber) ->
      audioParts = []
      
      # Буквенная часть — всё до номера в конце: сокращение бывает из нескольких
      # букв и в разном регистре («ПХр»), и запись ищется по нему целиком
      ticketNumber = String(ticketNumber)
      letters = ticketNumber.replace(/\d+$/, '').trim()
      if letters
        audioParts.push("abbr_#{letters}")

      numbers = ticketNumber.match(/\d+$/)?[0] || ''
      if numbers
        numberInt = parseInt(numbers, 10)
        if numberInt > 0 && numberInt <= 99
          if numberInt <= 19
            # Для чисел от 1 до 19 используем прямое соответствие
            audioParts.push("number_#{numberInt}")
          else
            # Для чисел от 20 до 99
            tens = Math.floor(numberInt / 10) * 10
            ones = numberInt % 10
            
            # Добавляем десятки (20, 30, 40 и т.д.)
            audioParts.push("number_#{tens}")
            
            # Добавляем единицы, если число не круглое
            if ones > 0
              audioParts.push("number_#{ones}")
      
      # Добавляем "окно номер X"
      audioParts.push("window_#{windowNumber}")
      
      audioParts

    # Создаёт склеенный аудио-буфер из массива названий звуков
    mergeAudioBuffers: (soundNames) ->
      buffers = soundNames
        .map((name) => @audioBuffers[name])
        .filter((buffer) -> buffer?) # Убираем отсутствующие буферы

      return null if buffers.length == 0
      
      totalLength = buffers.reduce((sum, buffer) ->
        sum + buffer.length
      , 0)

      # Склейка всегда в моно: записи загружают разные люди, и стерео-кусок
      # после моно-куска обращался бы к несуществующему каналу склейки —
      # getChannelData бросает исключение, и пропадает всё объявление.
      # Частоту приводить не нужно: decodeAudioData уже вернул все буферы
      # в частоте аудиоконтекста.
      mergedBuffer = @audioContext.createBuffer(1, totalLength, @audioContext.sampleRate)
      outputData = mergedBuffer.getChannelData(0)

      offset = 0
      for buffer in buffers
        channels = (buffer.getChannelData(channel) for channel in [0...buffer.numberOfChannels])
        for i in [0...buffer.length]
          sum = 0
          sum += data[i] for data in channels
          outputData[offset + i] = sum / channels.length
        offset += buffer.length

      mergedBuffer

    playSound: (soundNameOrTicketInfo) ->
      buffer = null
      if typeof soundNameOrTicketInfo == 'string'
        buffer = @audioBuffers[soundNameOrTicketInfo]
      else
        {ticketNumber, windowNumber} = soundNameOrTicketInfo
        audioParts = @getAudioPartsForTicket(ticketNumber, windowNumber)
        buffer = @mergeAudioBuffers(audioParts)

      return unless buffer
    
      # Добавляем звук в очередь
      @soundQueue.push(buffer)
      
      # Запускаем воспроизведение, если оно еще не идет
      @playNextSound() unless @audioIsCurrentlyPlaying

    # Воспроизводит следующий звук из очереди
    playNextSound: ->
      return if @soundQueue.length == 0
      
      @audioIsCurrentlyPlaying = true
      buffer = @soundQueue.shift()
      
      source = @audioContext.createBufferSource()
      source.buffer = buffer
      source.connect(@audioContext.destination)
      
      # Устанавливаем обработчик окончания воспроизведения
      source.onended = => 
        @audioIsCurrentlyPlaying = false
        if @soundQueue.length > 0
          setTimeout(=>
            @playNextSound()
          , 100)
      
      source.start()

    loadSound: (soundName) ->
      audioPath = @audioPaths[soundName]
      console.log('load sound')
      return Promise.reject("Звук #{soundName} не найден") unless audioPath

      fetch(audioPath)
        .then((response) =>
          if !response.ok
            console.log("HTTP ошибка! статус: #{response.status}")
          response.arrayBuffer()
        )
        .then((arrayBuffer) => @audioContext.decodeAudioData(arrayBuffer))
        .then((audioBuffer) =>
          @audioBuffers[soundName] = audioBuffer
          console.log("Загружен звук: #{soundName}")
        )
        .catch((error) => console.error("Ошибка загрузки звука #{soundName}:", error))

  $(document).ready ->
    window.createColorizedTicketNumber = (ticketNumber) ->
      $container = $('<span>').addClass('ticket-info')
      
      String(ticketNumber).split('').forEach (char) ->
        $span = $('<span>')
        if /\d/.test(char)
          $span.addClass('digit-color')
        else
          $span.addClass('letter-color')
        $span.text(char)
        $container.append($span)
      
      return $container

    window.waitingTicketsDisplay = new WaitingTicketsDisplay()
    window.audioPlayer = new AudioPlayer()
