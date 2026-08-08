$(document).on 'click', '.done_status>a', (event)->
  $input = $(this).closest('.done_status').next('input')
  $input.val($(this).data('value'))
  event.preventDefault()

$(document).on 'change', '.breakage-report__toggle', ->
  $(this).closest('.breakage-report').find('.breakage-report__fields').toggleClass('hidden', !@checked)
