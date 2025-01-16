jQuery ->
  $('.help-tooltip').tooltip()

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
        labelText = $span.find('label.collection_check_boxes').text().toLowerCase()
        if labelText.indexOf(filterText) == -1
          $span.hide()
        else
          $span.show()

  $('.kanban-board').each ->
    $board = $(this)
    backgroundColor = $board.data('background') || '#ffffff'
    $board.css 'background-color', backgroundColor
    fontColor = $board.data('font-color')
    if fontColor && fontColor.trim() != ''
      $board.find('.kanban-card a').css 'color', fontColor
    fontSize = $board.data('font-size')
    if fontSize && fontSize.toString().trim() != ''
      $board.find('.kanban-card a').css 'font-size', "#{fontSize}px"

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
