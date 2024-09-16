$ ->
  $('.custom-select-wrapper').each ->
    $wrapper = $(this)
    $hiddenInput = $wrapper.find('input[type="hidden"]')
    selectedValue = $hiddenInput.val()

    $wrapper.find('.custom-option').each ->
      $option = $(this)
      optionValue = $option.data('value').toString()

      if optionValue == selectedValue
        $option.addClass('selected')
        optionColor = $option.data('color')
        optionText = $option.text()

        $trigger = $wrapper.find('.custom-select__trigger')
        $span = $trigger.find('span')
        $trigger.css('background-color', optionColor)
        $span.text(optionText)
      else
        $option.removeClass('selected')

  $(document).on 'click', '.custom-select__trigger', (event) ->
    event.stopPropagation()
    select = $(this).closest('.custom_select')
    $('.custom_select').not(select).removeClass('open')
    select.toggleClass('open')

    if select.hasClass('open')
      select.find('.custom-option.selected').addClass('hover')
      select.find('.custom-option').each ->
        color = $(this).data('color')
        $(this).css('background-color', color) if color
    else
      select.find('.custom-option').removeClass('hover')

  $(document).on 'click', '.custom-option', (event) ->
    event.stopPropagation()
    select = $(this).closest('.custom_select')
    wrapper = $(this).closest('.custom-select-wrapper')
    hiddenInput = wrapper.find('input[type="hidden"]')
    trigger = select.find('.custom-select__trigger')
    selectedValue = $(this).data('value')
    selectedColor = $(this).data('color')

    trigger.find('span').text($(this).text())
    trigger.css('background-color', selectedColor)
    select.find('.custom-option').removeClass('selected')
    hiddenInput.val(selectedValue)
    $(this).addClass('selected')
    select.removeClass('open')

  $(document).on 'click', ->
    $('.custom_select').removeClass('open')

  $(document).on 'keydown', (event) ->
    if event.key in ['Enter', ' '] and $('.custom_select.open').length
      event.preventDefault()
      $('.custom_select.open').find('.custom-option.hover').trigger('click')

  $(document).on 'mouseenter', '.custom-option', ->
    $(this).addClass('hover')

  $(document).on 'mouseleave', '.custom-option', ->
    $(this).removeClass('hover')

  $(document).on 'keydown', (event) ->
    select = $('.custom_select.open')
    if select.length and event.key in ['ArrowUp', 'ArrowDown']
      event.preventDefault()
      options = select.find('.custom-option')
      currentIndex = options.index(options.filter('.hover'))
      newIndex = if event.key is 'ArrowUp' then currentIndex - 1 else currentIndex + 1
      newIndex = Math.max(0, Math.min(newIndex, options.length - 1))
      options.eq(newIndex).addClass('hover').siblings().removeClass('hover')