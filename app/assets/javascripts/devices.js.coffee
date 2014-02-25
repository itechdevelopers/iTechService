jQuery ->

  $device_form = $('form.device_form')

  $('.device_comment_tooltip').tooltip()

  $('.device_progress').tooltip
    placement: 'left'
    html: true

  if $device_form.length > 0

    $(document).on 'change', '.device_task_task', () ->
      task_id = $(this).val()
      task_cost = $(this).parents('.device_task').find('.device_task_cost')
      $.getJSON '/tasks/'+task_id+'.json', (data) ->
        task_cost.val data.cost

    $('a', '#locations_list').click (event) ->
      $('#location_value').text $(this).text()
      $('#device_location_id').val $(this).attr('location_id')
      event.preventDefault()

    $('#device_security_code_none').click (event)->
      $('#device_security_code').val '-'
      event.preventDefault()

    $(document).on 'click', '#questionnaire_link', (event)->
      $this = $ this
      params = $this.parents('form:first').serialize()
      event.currentTarget.href = '/clients/questionnaire?' + params

  $('#device_serial_number').keydown (event)->
    $this = $(this)
    if (event.keyCode in [65..90]) and (event.metaKey is false) and (event.ctrlKey is false) and (event.altKey is false)
      $this.val($this.val()+String.fromCharCode(event.keyCode))
      event.preventDefault()

  $('#device_imei').blur ()->
    $.getJSON '/devices/check_imei?imei_q='+$(this).val(), (data)->
      if data.present
        $('#device_imei').parents('.control-group').addClass 'warning'
        if $('#device_imei').siblings('.help-inline').length
          $('#device_imei').siblings('.help-inline').html data.msg
        else
          $('#device_imei').parents('.controls').append "<span class='help-inline'>"+data.msg+"</span>"
      else
        $('#device_imei').parents('.control-group').removeClass 'warning'
        $('#device_imei').siblings('.help-inline').remove()

  $('#device_imei_search, #device_serial_number_search').click ()->
    $this = $(this)
    val = $this.prev('input').val()
    if val isnt ''
      $.getJSON '/items?q=' + val, (res)->
        $this.parent().siblings('.sales_info').remove()
        if res.id
          $('#device_item_id').val res.id
          $('#device_type_name').text res.name
          $('.device_form .imei_input').addClass 'hidden'
          for feature in res.features
            if feature.kind is 'imei'
              $('#device_imei').closest('.imei_input').removeClass 'hidden'
            $("#device_#{feature.kind}").val feature.value
          info_s = res.name
        else
          $('#device_item_id').val null
          $('#device_type_name').text '-'
          info_s = res.message
        $this.parent().after "<span class='help-inline sales_info'>#{info_s}</span>"

  $('#new_device_popup').mouseleave ->
    setTimeout (->
      $('#new_device_popup').fadeOut()
    ), 1000


$(document).on 'click', '.returning_device_tooltip', ->
  $(this).tooltip()
  $(this).tooltip('toggle')

PrivatePub.subscribe '/devices/new', (data, channel)->
  if data.device.location_id == $('#profile_link').data('location')
    $('#new_device_popup').fadeIn()

PrivatePub.subscribe '/devices/returning_alert', (data, channel)->
  $.getScript '/announcements/'+data.announcement_id
