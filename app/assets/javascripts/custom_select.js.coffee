$ ->
  $(document).on 'click', '.custom-select__trigger', (event) ->
    event.stopPropagation()
    select = $(this).closest('.custom_select')
    $('.custom_select').not(select).removeClass('open')
    select.toggleClass('open')

    if select.hasClass('open')
      select.find('.custom-option').each ->
        color = $(this).data('color')
        $(this).css('background-color', color) if color

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