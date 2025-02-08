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

    archive: (ticketNumber) ->
      window.waitingTicketsDisplay?.removeTicket(ticketNumber)

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
      window.audioPlayer?.playSound({ ticketNumber: ticketNumber, windowNumber: windowNumber })
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

  class AudioPlayer

    @ABBREVIATION_MAP = Object.freeze({
      'КК': 'kk'
      'СП': 'sp'
      'СВ': 'sv'
      'СС': 'ss'
      'СД': 'sd'
      'ПК': 'pk'
      'ПТ': 'pt'
      'ПБ': 'pb'
      'ПД': 'pd'
    })

    constructor: ->
      @audioBuffers = {}
      @audioContext = null
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
      Object.keys(AUDIO_PATHS).forEach (soundName) =>
        @loadSound(soundName)

    # Преобразует номер талона в массив названий аудио-файлов
    getAudioPartsForTicket: (ticketNumber, windowNumber) ->
      audioParts = []
      
      # Разбираем буквенную часть
      letters = ticketNumber.match(/[А-Я]+/)?[0] || ''
      if letters
        latinLetters = AudioPlayer.ABBREVIATION_MAP[letters]
        audioParts.push("abbr_#{latinLetters}") 

      numbers = ticketNumber.match(/\d+/)?[0] || ''
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

      mergedBuffer = @audioContext.createBuffer(
        buffers[0].numberOfChannels,
        totalLength,
        buffers[0].sampleRate
      )

      # Склеиваем буферы
      offset = 0
      for buffer in buffers
        # Для каждого канала
        for channel in [0...buffer.numberOfChannels]
          inputData = buffer.getChannelData(channel)
          outputData = mergedBuffer.getChannelData(channel)
          
          # Копируем данные с учётом смещения
          for i in [0...inputData.length]
            outputData[offset + i] = inputData[i]
        
        offset += buffer.length

      mergedBuffer

    playSound: (soundNameOrTicketInfo) ->
      if typeof soundNameOrTicketInfo == 'string'
        buffer = @audioBuffers[soundNameOrTicketInfo]
      else
        {ticketNumber, windowNumber} = soundNameOrTicketInfo
        audioParts = @getAudioPartsForTicket(ticketNumber, windowNumber)
        buffer = @mergeAudioBuffers(audioParts)

      return unless buffer

      source = @audioContext.createBufferSource()
      source.buffer = buffer
      source.connect(@audioContext.destination)
      source.start()

    loadSound: (soundName) ->
      audioPath = window.AUDIO_PATHS[soundName]
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
    window.waitingTicketsDisplay = new WaitingTicketsDisplay()
    window.audioPlayer = new AudioPlayer()
