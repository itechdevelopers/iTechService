# Main question visibility handler for check lists
$ ->
  # Function to toggle subordinate questions visibility
  toggleSubordinateQuestions = (checkList) ->
    mainQuestion = checkList.find('.main-question-checkbox')
    subordinateContainer = checkList.find('.subordinate-questions')

    if mainQuestion.length > 0 && subordinateContainer.length > 0
      if mainQuestion.is(':checked')
        subordinateContainer.show()
      else
        subordinateContainer.hide()

  # Initialize on page load for device task modal
  $(document).on 'shown.bs.modal', '#modal-form', ->
    $('.check-list-container').each ->
      toggleSubordinateQuestions($(this))

  # Handle main question checkbox change
  $(document).on 'change', '.main-question-checkbox', ->
    checkList = $(this).closest('.check-list-container')
    toggleSubordinateQuestions(checkList)

  # Initialize on AJAX content load
  $(document).on 'ajax:success', (event, data, status, xhr) ->
    setTimeout ->
      $('.check-list-container').each ->
        toggleSubordinateQuestions($(this))
    , 100

  # For check list edit form - update main question dropdown when items change
  $(document).on 'nested:fieldAdded', '#check-list-items', (event) ->
    updateMainQuestionDropdown()

  $(document).on 'nested:fieldRemoved', '#check-list-items', (event) ->
    setTimeout ->
      updateMainQuestionDropdown()
    , 100

  updateMainQuestionDropdown = ->
    select = $('#check_list_main_question_id')
    return unless select.length > 0

    currentValue = select.val()
    select.empty()
    select.append($('<option>').val('').text(''))

    $('#check-list-items .nested-fields:visible').each (index) ->
      questionInput = $(this).find('input[id$="_question"]')
      questionText = questionInput.val() || "Вопрос #{index + 1}"
      itemId = $(this).find('input[id$="_id"]').val()

      if itemId
        select.append($('<option>').val(itemId).text(questionText))

    select.val(currentValue)