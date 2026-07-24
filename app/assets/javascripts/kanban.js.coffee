jQuery ->
  $('.help-tooltip').tooltip()

  window.initKanbanCardsSortable = (list) ->
    i = 0
    list.each (_index, element) ->
      console.log(i++)
      new Sortable(element, {
                  group: 'cards',
                  animation: 300,
                  onEnd: (e) =>
                    saveCardsSorting($('.kanban-card'))
                  })

  window.saveCardsSorting = (newList) ->
    cardIds = []
    newList.each (i, element) ->
      colId = $(element).closest('.kanban-column-cards').attr('data-column-id')
      cardId = $(element).attr('data-card-id')
      cardIds.push({
       'id': cardId,
       'column_id': colId
      })
    $('#card-positions').val(JSON.stringify(cardIds))
    $('#update-card-columns-form').submit()

  if $('#update-card-columns-form').length
    initKanbanCardsSortable $('.kanban-card-container')

  $(document).on 'change', '.kanban-manager-checkbox', ->
    toggleEmailWarning(this)

  $(".check-all-users").on "click", (event) ->
    event.preventDefault()
    $(this).closest(".kanban-user-choice").find(":checkbox").prop "checked", true

  $(".uncheck-all-users").on "click", (event) ->
    event.preventDefault()
    $(this).closest(".kanban-user-choice").find(":checkbox").prop "checked", false

  $(".filter-kanban-users").on "input", ->
    filterText = $(this).val().toLowerCase()
    $parent = $(this).closest(".kanban-user-choice")
    $spans = $parent.find("span")
    if filterText == ""
      $spans.show()
    else
      $spans.each ->
        $span = $(this)
        labelText = $span.find('label').text().toLowerCase()
        if labelText.indexOf(filterText) == -1
          $span.hide()
        else
          $span.show()

  $('.kanban-board').each ->
    $board = $(this)
    backgroundColor = $board.data('background') || '#ffffff'
    $board.css 'background-color', backgroundColor
    bgImage = $board.data('bg-image')
    if bgImage && bgImage.toString().trim() != ''
      # Tile the image at its natural size instead of stretching it to fill.
      # `cover` scaled portrait/low-res uploads up and cropped them, which read
      # as "stretched"; `repeat` + `auto` always shows the image 1:1, so it can
      # never distort — at the cost of visible seams for non-tileable photos.
      $board.css
        'background-image': "url(#{bgImage})"
        'background-repeat': 'repeat'
        'background-size': 'auto'
        'background-position': 'top left'
    fontColor = $board.data('font-color')
    if fontColor && fontColor.trim() != ''
      $board.find('.kanban-card a').css 'color', fontColor
    fontSize = $board.data('font-size')
    if fontSize && fontSize.toString().trim() != ''
      $board.find('.kanban-card a').css 'font-size', "#{fontSize}px"
    # White-card mode is a readable "package": white background + black text.
    # Applied last so it wins over card_font_color set above.
    whiteCards = $board.data('white-cards')
    if whiteCards == true || whiteCards == 'true'
      $board.find('.kanban-card').css 'background-color', '#ffffff'
      $board.find('.kanban-card a').css 'color', '#000000'

  $('.kanban-card-content').each ->
    $card = $(this)
    fontSize = $card.data('font-size')
    if fontSize && fontSize.toString().trim() != ''
      $card.css 'font-size', "#{fontSize}px"

  toggleEmailWarning = (checkbox) ->
    $label = $(checkbox).next('label')
    $warning = $label.next('.email-warning')

    if $(checkbox).is(':checked') && $(checkbox).data('email') == false
      if $warning.length == 0
        $warning = $('<span class="email-warning">У данного пользователя не указан email</span>')
        $label.after($warning)
    else
      $warning.remove()
