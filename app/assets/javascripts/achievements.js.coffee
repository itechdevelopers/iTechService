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

  $(document).on 'change', 'select[data-action="achievement#preview"]', ->
    achievement_id = $(this).val()
    form = $(this).closest('form')
    $.get "/achievements/#{achievement_id}/icon_url", dataType: 'json', (data) ->
      form.find('.achievement-icon').attr('src', data.icon_url)