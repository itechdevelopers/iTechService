# Picks black or white text for a given background so options stay readable
# on dark department colors. Returns '' for a blank color (leave CSS default).
contrastColor = (hex) ->
  return '' unless hex
  c = hex.toString().replace('#', '')
  c = c.split('').map((ch) -> ch + ch).join('') if c.length == 3
  return '' unless c.length == 6
  r = parseInt(c.substr(0, 2), 16)
  g = parseInt(c.substr(2, 2), 16)
  b = parseInt(c.substr(4, 2), 16)
  luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if luminance > 0.6 then '#000000' else '#ffffff'

# Applies a background color plus a contrasting text color to an element.
paintOption = ($el, color) ->
  $el.css
    'background-color': color or ''
    'color': contrastColor(color)

# Syncs each custom-select trigger (text + color) with its hidden field's
# current value. Exposed globally so AJAX-injected content (e.g. modal forms)
# can re-init after render — the document-ready pass below only covers the
# markup present on first page load.
window.initCustomSelects = (context = document) ->
  $('.custom-select-wrapper', context).each ->
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
        paintOption($trigger, optionColor)
        $span.text(optionText)
      else
        $option.removeClass('selected')

$ ->
  initCustomSelects()

  $(document).on 'click', '.custom-select__trigger', (event) ->
    event.stopPropagation()
    select = $(this).closest('.custom_select')
    $('.custom_select').not(select).removeClass('open')
    select.toggleClass('open')

    if select.hasClass('open')
      select.find('.custom-option.selected').addClass('hover')
      select.find('.custom-option').each ->
        paintOption($(this), $(this).data('color'))
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

    trigger.find('span').html($(this).html())
    paintOption(trigger, selectedColor)
    select.find('.custom-option').removeClass('selected')
    hiddenInput
      .val(selectedValue)
      .trigger('customSelect:change', [selectedValue])
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