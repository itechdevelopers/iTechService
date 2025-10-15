# Main question visibility handler for check lists
$ ->
  # Store the previously selected radio button for unchecking
  lastChecked = null

  # Allow unchecking radio buttons by clicking the same option again
  $(document).on 'click', '.radio-group input[type="radio"]', (e) ->
    radio = $(this)

    # If clicking the same radio that was already checked, uncheck it
    if radio.is(lastChecked)
      radio.prop('checked', false)
      lastChecked = null

      # Trigger change event for subordinate question logic
      radio.trigger('change')
    else
      # Store this radio as the last checked
      lastChecked = radio

  # Function to toggle subordinate questions visibility based on radio selection
  toggleSubordinateQuestions = (checkList) ->
    # Find the 'yes' radio button for the main question
    mainQuestionYes = checkList.find('.main-question-radio[value="yes"]')
    subordinateContainer = checkList.find('.subordinate-questions')

    if mainQuestionYes.length > 0 && subordinateContainer.length > 0
      if mainQuestionYes.is(':checked')
        subordinateContainer.show()
        # Enable radio buttons in subordinate questions
        subordinateContainer.find('input[type="radio"]').prop('disabled', false)
      else
        subordinateContainer.hide()
        # Clear subordinate question selections when main is 'no'
        subordinateContainer.find('input[type="radio"]').prop('checked', false)
        # Optionally disable them to prevent accidental selection
        subordinateContainer.find('input[type="radio"]').prop('disabled', true)

  # Initialize on page load (for regular forms like ServiceJob)
  $(document).ready ->
    $('.check-list-container').each ->
      toggleSubordinateQuestions($(this))

  # Initialize on page load for device task modal
  $(document).on 'shown.bs.modal', '#modal-form', ->
    $('.check-list-container').each ->
      toggleSubordinateQuestions($(this))

  # Handle main question radio button change
  $(document).on 'change', '.main-question-radio', ->
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

  # Visual validation highlighting for checklist questions
  highlightCheckListErrors = (container) ->
    # Check if this checklist has a main question
    mainQuestionRadio = container.find('.main-question-radio')

    if mainQuestionRadio.length > 0
      # Has main question - check if it's required and answered
      isRequired = mainQuestionRadio.first().prop('required')
      mainAnswered = container.find('.main-question-radio:checked').length > 0

      if isRequired && !mainAnswered
        # Add error state to container
        container.addClass('error')
        # Add error message if not already present
        unless container.find('.checklist-error-message').length > 0
          errorMsg = $('<span>').addClass('help-inline text-error checklist-error-message')
                                .text('Пожалуйста, ответьте на обязательный вопрос')
          container.find('.check-list-question-group:first .radio-group').after(errorMsg)
      else
        # Remove error state
        container.removeClass('error')
        container.find('.checklist-error-message').remove()

        # If main question answered "yes", check subordinate questions
        if mainAnswered
          mainValue = container.find('.main-question-radio:checked').val()
          if mainValue == 'yes'
            subordinateQuestions = container.find('.subordinate-questions .check-list-question-group')
            subordinateQuestions.each ->
              questionGroup = $(this)
              requiredMarker = questionGroup.find('.required')
              isSubRequired = requiredMarker.length > 0
              radios = questionGroup.find('input[type="radio"]')
              isAnswered = radios.filter(':checked').length > 0

              if isSubRequired && !isAnswered
                questionGroup.addClass('error')
                unless questionGroup.find('.question-error-message').length > 0
                  errorMsg = $('<span>').addClass('help-inline text-error question-error-message')
                                        .text('Обязательный вопрос')
                  questionGroup.find('.radio-group').after(errorMsg)
              else
                questionGroup.removeClass('error')
                questionGroup.find('.question-error-message').remove()
    else
      # No main question - check all required questions
      container.find('.check-list-question-group').each ->
        questionGroup = $(this)
        requiredMarker = questionGroup.find('.required')
        isRequired = requiredMarker.length > 0
        radios = questionGroup.find('input[type="radio"]')
        isAnswered = radios.filter(':checked').length > 0

        if isRequired && !isAnswered
          questionGroup.addClass('error')
          unless questionGroup.find('.question-error-message').length > 0
            errorMsg = $('<span>').addClass('help-inline text-error question-error-message')
                                  .text('Обязательный вопрос')
            questionGroup.find('.radio-group').after(errorMsg)
        else
          questionGroup.removeClass('error')
          questionGroup.find('.question-error-message').remove()

  # Check if checklist has validation errors
  hasCheckListErrors = (form) ->
    hasErrors = false
    form.find('.check-list-container').each ->
      container = $(this)
      mainQuestionRadio = container.find('.main-question-radio')

      if mainQuestionRadio.length > 0
        isRequired = mainQuestionRadio.first().prop('required')
        mainAnswered = container.find('.main-question-radio:checked').length > 0

        # Main question required but not answered
        if isRequired && !mainAnswered
          hasErrors = true
          return false  # break from each loop

        # If main answered "yes", check subordinates
        if mainAnswered
          mainValue = container.find('.main-question-radio:checked').val()
          if mainValue == 'yes'
            subordinateQuestions = container.find('.subordinate-questions .check-list-question-group')
            subordinateQuestions.each ->
              questionGroup = $(this)
              requiredMarker = questionGroup.find('.required')
              radios = questionGroup.find('input[type="radio"]')

              if requiredMarker.length > 0 && radios.filter(':checked').length == 0
                hasErrors = true
                return false  # break
      else
        # No main question - check all required
        container.find('.check-list-question-group').each ->
          questionGroup = $(this)
          requiredMarker = questionGroup.find('.required')
          radios = questionGroup.find('input[type="radio"]')

          if requiredMarker.length > 0 && radios.filter(':checked').length == 0
            hasErrors = true
            return false  # break

    hasErrors

  # Form submit handler - prevent submission if validation fails
  $(document).on 'submit', 'form[id^="edit_device_task"]', (e) ->
    form = $(this)

    # Only validate if there are checklists
    if form.find('.check-list-container').length > 0
      if hasCheckListErrors(form)
        e.preventDefault()

        # Mark form as having attempted submission
        form.data('validation-attempted', true)

        # Show visual errors
        form.find('.check-list-container').each ->
          highlightCheckListErrors($(this))

        # Scroll to first error
        firstError = form.find('.check-list-container.error').first()
        if firstError.length > 0
          firstError[0].scrollIntoView({ behavior: 'smooth', block: 'center' })

        return false

    true

  # Validate checklists on radio button change (only if validation already attempted)
  $(document).on 'change', '.check-list-container input[type="radio"]', ->
    form = $(this).closest('form')

    # Only show visual feedback if form has been submitted at least once
    if form.data('validation-attempted')
      container = $(this).closest('.check-list-container')
      highlightCheckListErrors(container)

  # When modal re-renders with server errors, mark as validation-attempted and show errors
  $(document).on 'shown.bs.modal', '#modal-form', ->
    form = $('#modal-form').find('form')

    # If there are validation errors from server, mark form and show visual errors
    if form.find('.alert-error').length > 0
      form.data('validation-attempted', true)
      $('.check-list-container').each ->
        highlightCheckListErrors($(this))