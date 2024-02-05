jQuery ->

  $service_job_form = $('form.service_job_form')

  $('.service_job_comment_tooltip').tooltip()

  $('.service_job_progress').tooltip
    placement: 'left'
    html: true

  if $service_job_form.length > 0
    $service_job_form.find('label.important').tooltip(title: 'Информация, которая заполняется здесь, отображается в заказ-наряде. Будьте внимательны.')

    $(document).on 'change', '.device_task_task', () ->
      task_id = $(this).val()
      $row = $(this).parents('.device_task')
      task_cost = $row.find('.device_task_cost')
      is_change_location = $row.is(':first-child')
      item_id = $('#service_job_item_id').val()
      department_id = $('[name="service_job[department_id]"]:checked').val()

      $.getJSON "/tasks/#{task_id}.json", {department_id: department_id}, (data)->
        task_cost.val data.cost

        if is_change_location
          $('#location_id').val(data.location_id)
          $('#location_value').text(data.location_name)

        if data['is_repair?']
          document.getElementById('service_job_notify_client').checked = true

      $.getJSON "/tasks/#{task_id}/device_validation", {item_id: item_id}, (data)->
        alert(data['message']) if data['message']

    $(document).on 'focus', '.device_task_comment', ->
      $(this).popover(trigger: 'focus', placement: 'top', html: true)

#    $(document).on 'change', '.device_task:first-child .device_task_task', ->
#      task_id = $(this).val()
#      unless task_id is ''
#        $.getJSON "/tasks/#{task_id}.json", (data)->
#          $field = $('#location_id')
#          if $field.find("[value='#{data.location_id}']").length == 0
#            $field.append "<option value='#{data.location_id}'>#{data.location_name}</option>"
#          $field.val(data.location_id)

    $('#service_job_security_code_none').click (event)->
      $('#service_job_security_code').val '-'
      event.preventDefault()

    $('#service_job_contact_phone_none').click (event)->
      $('#service_job_contact_phone').val '-'
      event.preventDefault()

    $('#service_job_contact_phone_copy').click (event)->
      client_phone = $('#client_search').val().split('/')[1].match(/[0-9]/g).join('')
      $('#service_job_contact_phone').val client_phone
      event.preventDefault()

    $fields_with_templates = $service_job_form.find('.has-templates')

    $fields_with_templates.focus ->
      $(this).popover('show')

    $fields_with_templates.blur ->
      $(this).popover('hide')

    $(document).on 'click', '.service-job_template', ->
      content = this.innerText
      $input = $(this).closest('.controls').find('.has-templates')
      old_value = $input.val()
      new_value = old_value + ' ' + content
      $input.val(new_value.trim())

#  $('#service_job_imei').blur ()->
#    $.getJSON '/service_jobs/check_imei?imei_q='+$(this).val(), (data)->
#      if data.present
#        $('#service_job_imei').parents('.control-group').addClass 'warning'
#        if $('#service_job_imei').siblings('.help-inline').length
#          $('#service_job_imei').siblings('.help-inline').html data.msg
#        else
#          $('#service_job_imei').parents('.controls').append "<span class='help-inline'>"+data.msg+"</span>"
#      else
#        $('#service_job_imei').parents('.control-group').removeClass 'warning'
#        $('#service_job_imei').siblings('.help-inline').remove()

  $('#service_job_imei_search, #service_job_serial_number_search').click ()->
    $this = $(this)
    val = $this.prev('input').val()
    if val isnt ''
      $.getJSON '/imported_sales?search='+val, (res)->
        info_tag = "<span class='help-inline imported_sales_info'>"
        if res.length > 0
          for r in res
            d = new Date(r.sold_at)
            info_tag += '[' + d.toLocaleDateString() + ': ' + r.quantity + '] '
        else
          info_tag += res.message
        info_tag += "</span>"
        $this.parent().siblings('.imported_sales_info').remove()
        $this.parent().after info_tag
      $.getJSON '/items?saleinfo=1&q=' + val, (res)->
        $this.parent().siblings('.sales_info').remove()
        if res.id
          if res.sale_info
            info_s = res.sale_info
          else
            info_s = '-'
        else
          info_s = res.message
        $this.parent().after "<span class='help-inline sales_info'>#{info_s}</span>"

  $('#new_service_job_popup').mouseleave ->
    setTimeout (->
      $('#new_service_job_popup').fadeOut()
    ), 1000

  $('#check_imei_link').click ->
    imei = $(this).parent().find('input').val()
    this.setAttribute('href', "http://iunlocker.net/check_imei.php?imei=#{imei}")

$(document).on 'click', '#service_job_client_notified_false',  (event)->
  service_job_id = document.getElementById('service_job_form').action.match(/\d+$/)[0]
  $.getScript("/service/sms_notifications/new?service_job_id=#{service_job_id}")

$(document).on 'click', '.returning_device_tooltip', ->
  $(this).tooltip()
  $(this).tooltip('toggle')

$(document).on 'click', '#completion_act_link', ->
  $('#service_job_archive_button').removeClass('hidden')

$(document).on 'click', '.add-photo-btn a', (event) ->
  console.log("HERE")

#TODO implement via cable
#PrivatePub.subscribe '/service_jobs/new', (data, channel)->
#  if data.service_jobs.location_id == $('#profile_link').data('location')
#    $('#new_service_job_popup').fadeIn()
#TODO implement via cable
#PrivatePub.subscribe '/service_jobs/returning_alert', (data, channel)->
#  $.getScript '/announcements/'+data.announcement_id