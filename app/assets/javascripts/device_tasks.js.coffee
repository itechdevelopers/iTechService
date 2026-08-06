$(document).on 'click', '.done_status>a', (event)->
  $input = $(this).closest('.done_status').next('input')
  $input.val($(this).data('value'))
  event.preventDefault()

$(document).on 'change', '.breakage-report__toggle', ->
  $(this).closest('.breakage-report').find('.breakage-report__fields').toggleClass('hidden', !@checked)

# The modal arrives over AJAX, so jQuery UI can't be bound upfront — attach the
# widget on first focus instead.
$(document).on 'focus', '.breakage-report__item-search', ->
  return if $(this).data('uiAutocomplete')

  $(this).autocomplete
    source: '/items/spare_parts_autocomplete.json'
    minLength: 2
    # The jQuery UI theme leaves .ui-autocomplete without a z-index, so inside a
    # Bootstrap modal (z-index 1050) the suggestion list renders underneath it.
    open: ->
      $(this).autocomplete('widget').css('z-index', 1060)
    select: (event, ui) ->
      # Out-of-stock parts are listed so the technician sees the zero remainder,
      # but picking one is a no-op: the write-off would fail anyway.
      return false if ui.item.available < 1
      $(this).val(ui.item.label)
      $(this).siblings('.breakage-report__item-id').val(ui.item.value)
      false
    focus: (event, ui) ->
      return false if ui.item.available < 1
      $(this).val(ui.item.label)
      false
    change: (event, ui) ->
      $(this).siblings('.breakage-report__item-id').val('') unless ui.item

  $(this).autocomplete('instance')._renderItem = (ul, item) ->
    classes = if item.available < 1 then 'breakage-report__suggestion--empty' else ''
    $("<li class='#{classes}'>").append($('<a>').text(item.label)).appendTo(ul)