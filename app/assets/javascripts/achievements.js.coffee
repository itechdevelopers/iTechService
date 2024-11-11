$ ->
  $(document).on 'click', '.add-achievement-btn', (e) ->
    e.preventDefault()
    $('#add-achievement').addClass('hidden')
    url = $(e.currentTarget).data('url')
    $.get url, dataType: 'script'

  $(document).on 'click', '.cancel-achievement-btn', (e) ->
    e.preventDefault()
    $(this).closest('.achievement-form').remove()
    $('#add-achievement').removeClass('hidden')

$(document).on 'customSelect:change', 'input[type="hidden"][data-action="achievement#preview"]', (event, selectedValue) ->
  return unless selectedValue

  form = $(this).closest('form')
  $.get "/achievements/#{selectedValue}/icon_url", dataType: 'json', (data) ->
    form.find('.achievement-icon').attr('src', data.icon_url)