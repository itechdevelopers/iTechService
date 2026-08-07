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

# Hides options that don't match every whitespace-separated token of the
# query, so "попов дми" finds "Дмитрий Попов" regardless of word order. The
# prompt option (empty data-value) is hidden while searching — it matches
# nothing meaningful and would just take a row. Highlights the first survivor
# so Enter picks it straight away.
applySearchFilter = ($select, query) ->
  tokens = (query or '').toLowerCase().split(/\s+/).filter (token) -> token.length > 0
  $select.find('.custom-option').each ->
    $option = $(this)
    isPrompt = $option.data('value').toString() == ''
    text = $option.text().toLowerCase()
    matches = tokens.every (token) -> text.indexOf(token) >= 0
    visible = matches and not (isPrompt and tokens.length > 0)
    $option.toggle(visible)
    $option.removeClass('hover') unless visible
  return unless tokens.length > 0
  $select.find('.custom-option').removeClass('hover')
  $select.find('.custom-option:visible').first().addClass('hover')

# Clears a previous query and focuses the field, so the list opens whole and
# the user can type immediately.
resetSearch = ($select) ->
  $search = $select.find('.custom-select__search-input')
  return unless $search.length
  $search.val('')
  applySearchFilter($select, '')
  $search.focus()

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
      resetSearch(select)
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

  # The search box lives inside the dropdown, so a click on it would bubble to
  # the document handler below and close the very list being filtered.
  $(document).on 'click', '.custom-select__search', (event) ->
    event.stopPropagation()

  $(document).on 'input', '.custom-select__search-input', ->
    applySearchFilter($(this).closest('.custom_select'), $(this).val())

  $(document).on 'click', ->
    $('.custom_select').removeClass('open')

  $(document).on 'keydown', (event) ->
    select = $('.custom_select.open')
    return unless select.length
    # Space is a plain character while typing in the search box — only treat it
    # as "pick the highlighted option" outside the field.
    inSearch = $(event.target).hasClass('custom-select__search-input')
    return if event.key is ' ' and inSearch

    if event.key in ['Enter', ' ']
      # preventDefault also keeps Enter in the search box from submitting the
      # surrounding form.
      event.preventDefault()
      option = select.find('.custom-option.hover:visible').first()
      option = select.find('.custom-option:visible').first() unless option.length
      option.trigger('click')

  $(document).on 'mouseenter', '.custom-option', ->
    $(this).addClass('hover')

  $(document).on 'mouseleave', '.custom-option', ->
    $(this).removeClass('hover')

  $(document).on 'keydown', (event) ->
    select = $('.custom_select.open')
    if select.length and event.key in ['ArrowUp', 'ArrowDown']
      event.preventDefault()
      # `:visible` so arrows walk only the options surviving the search filter.
      options = select.find('.custom-option:visible')
      currentIndex = options.index(options.filter('.hover'))
      newIndex = if event.key is 'ArrowUp' then currentIndex - 1 else currentIndex + 1
      newIndex = Math.max(0, Math.min(newIndex, options.length - 1))
      options.eq(newIndex).addClass('hover').siblings().removeClass('hover')