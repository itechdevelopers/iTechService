jQuery ->
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