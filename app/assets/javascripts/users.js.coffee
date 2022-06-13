jQuery ->

  new CarrierWaveCropper()

  $('.user-fautls').click ->
    $.get $(this).find('a').data('source')

  markedCells = [null, null, null, null]

  $('#schedule_table tbody').mousedown (event) ->
    event.preventDefault()

  $('.schedule_hour').click (event) ->
    $this = $(this)
    if event.shiftKey and ((markedCells[0] isnt null) and (markedCells[1] isnt null))
      markedCells[2] = $this.prop('cellIndex')
      markedCells[3] = $this.parent().prop('rowIndex')
      fill_schedule_hours markedCells
      markedCells = [null, null, null, null]
    else
      markedCells[0] = $this.prop('cellIndex')
      markedCells[1] = $this.parent().prop('rowIndex')
      toggle_schedule_day $this
    fill_schedule_fields()
    event.preventDefault()
    false

  $(document).on 'click', '.user_calendar.editable td.calendar_day.work_day.empty', (event)->
    $this = $(this)
    $fields = $('#duty_days_fields')
    this_date = $this.attr('date')
    $field_day = $("input[value=" + this_date + "]", $fields)

    if $field_day.length > 0
      fields_id = $field_day[0].id.match(/.+\d+_/)[0]
      $field_destroy = $("#" + fields_id + "_destroy", $fields)

    if $this.hasClass 'duty'
      if $field_destroy.length > 0
        $field_destroy.val 'true'
      else
        $field_day.remove()
      $this.removeClass 'duty'
    else
      if $field_day.length > 0
        $field_destroy.val 'false'
      else
        new_id = new Date().getTime()
        new_field = "<input id='user_duty_days_attributes_" + new_id + "_day' name='user[duty_days_attributes][" +
            new_id + "][day]' type='hidden' value='" + this_date + "'>"
        $fields.append new_field

      $this.addClass 'duty'
      alert('Укороченный день!') if $this.hasClass('shortened')

  $('#edit_wish_link').click (event) ->
    $('#wish_view, #wish_edit').toggleClass 'hide'

  $('#save_user_wish').click (event) ->
    $form = $('#update_user_wish_form')
    url = $form.attr('action') + '.json'
    data = $form.serialize()
    $.ajax(
        url: url
        data: data
        dataType: 'json'
        type: 'PUT'
      ).done((result) ->
        $("#wish_view").text result.wish
        $("#wish_view, #wish_edit").toggleClass("hide")
      ).fail (result, status) ->
        alert status
    event.preventDefault()

  $('#edit_uniform_link').click (event) ->
    $('#uniform_view, #uniform_edit').toggleClass 'hide'

  $('#edit_wishlist_hobby_link').click (event) ->
    $('#wishlist_hobby_view, #wishlist_hobby_edit').toggleClass 'hide'

  $(document).ready () ->
    $(".add_wishlist_fields").click (event) ->
      $("#wishlist_list").append($(this).data("field"))
      $('a.remove_field').click (event) ->
        $(this).closest('p').remove()
        event.preventDefault()
      event.preventDefault()

    $('a.remove_field').click (event) ->
      $(this).closest('p').remove()
      event.preventDefault()

  if $('#staff_schedule').length > 0
    $legend = $('#staff_schedule_legend')
    $table = $('#job_schedule_table')
    $('.user_name', $legend).click ->
      $this = $(this)
      $user_row = $(this).parents('.user_row')
      user = $user_row.data 'user'
      $job_schedule_row = $(".job_schedule_user_hours[data-user="+user+"]", $table)
      selected = $user_row.hasClass 'selected'
      $('.user_row.selected', $legend).removeClass 'selected'
      $user_row.addClass 'selected' unless selected
      $(".job_schedule_user_hours.selected", $table).removeClass 'selected'
      $job_schedule_row.addClass 'selected' unless selected

    $('.user_color>span', $legend).colorpicker()
      .on 'changeColor', (event)->
        $(this).css backgroundColor: event.color.toHex()
      .on 'hide', (event)->
        $this = $(this)
        user_id = $this.parents('.user_row').data 'user'
        color = event.color.toHex()
        $.ajax
          type: 'PUT'
          url: '/users/'+user_id
          data: {user: {color: color}}
          dataType: 'json'
          success: ->
            $hours_row = $('.job_schedule_user_hours[data-user='+user_id+']')
            $hours_row.data('color', color)
            $(".work_hour", $hours_row).css backgroundColor: color
          error: (jqXHR, textStatus, errorThrown)->
            console.log(jqXHR.status+' ('+errorThrown+')')

    $(document).on 'mouseenter', '#job_schedule_table .job_schedule_user_hours', ->
      user = $(this).data 'user'
      $('.user_row[data-user='+user+']', $legend).addClass 'hovered'
    $(document).on 'mouseleave', '#job_schedule_table .job_schedule_user_hours', ->
      $('.user_row.hovered', $legend).removeClass 'hovered'

    $('.add_user_to_job_schedule', $table).click (event)->
      user = $('.user_row.selected', $legend).data 'user'
      unless user is undefined
        $this = $ this
        day = $this.data 'day'
        unless $('.job_schedule_user_hours[data-user='+user+'][data-day='+day+']').length > 0
          $.getScript '/users/'+user+'/add_to_job_schedule?day='+day
      event.preventDefault()

    $(document).on 'click', '#job_schedule_table .job_schedule_user_hour', (event)->
      $this = $ this
      $this.toggleClass 'work_hour'
      color = if $this.hasClass('work_hour') then $this.parents('.job_schedule_user_hours').data('color') else 'inherit'
      $this.css backgroundColor: color
      event.preventDefault()

    $(document).on 'click', '.save_job_schedule_hours', (event)->
      $this = $ this
      $row = $this.parents('.job_schedule_user_hours:first')
      $cell = $this.parent()
      $buttons = $('a', $cell)
      $buttons.fadeOut 100
      day_id = $row.data('dayid')
      user_id = $row.data('user')
      hours = ''
      $hours = $('.job_schedule_user_hour.work_hour', $row)

      if $hours.length > 0
        hours = $hours.map( ->
                  $(this).data('hour')
                ).get().join()

      $.ajax
        type: 'PUT'
        url: '/users/'+user_id
        data: {user: {schedule_days_attributes: {'0': {id: day_id, hours: hours}}}}
        dataType: 'json'
        success: ->
          $cell.animate(
            backgroundColor: 'green'
          , 100).delay(100).animate(
            backgroundColor: 'inherit'
          , 100, ->
            $buttons.fadeIn(100)
          ).removeAttr('style')
        error: (jqXHR, textStatus, errorThrown)->
          $cell.animate(
            backgroundColor: 'red'
          , 100).delay(100).animate(
            backgroundColor: 'inherit'
          , 100, ->
            $buttons.fadeIn(100)
          ).removeAttr('style')
          console.log(jqXHR.status+' ('+errorThrown+')')

      event.preventDefault()

    $(document).on 'click', '.delete_job_schedule_hours', ->
      $this = $ this
      $row = $this.parents('.job_schedule_user_hours:first')
      $cell = $this.parent()
      $buttons = $('a', $cell)
      $buttons.fadeOut 100
      day_id = $row.data('dayid')
      user_id = $row.data('user')
      hours = ''

      $.ajax
        type: 'PUT'
        url: '/users/'+user_id
        data: { user: { schedule_days_attributes: { '0': { id: day_id, hours: hours } } } }
        dataType: 'json'
        success: ->
          $row.slideUp(400).remove()
        error: (jqXHR, textStatus, errorThrown)->
          $cell.animate(
            backgroundColor: 'red'
          , 100).delay(100).animate(
            backgroundColor: 'inherit'
          , 100, ->
            $buttons.fadeIn(100)
          ).removeAttr('style')
          console.log(jqXHR.status+' ('+errorThrown+')')

      event.preventDefault()

    $(document).on 'click', '.staff_calendar .calendar_day>span', (event) ->
      event.preventDefault()
      $this = $(this).parent()
      if $this.hasClass 'duty'
        day_id = $this.data('dayid')
        $.post '/users/destroy_duty_day', { duty_day_id: day_id }
      else if $this.hasClass('empty')
        user_id = $('.user_row.selected', $legend).data('user')
        unless user_id is null
          $user = $('.user_row.selected', $legend)
          color = $('.user_color>span', $user).data('color')
          day = $this.data('day')
          kind = $this.parents('.staff_calendar').data('kind')
          $.post '/users/create_duty_day', { duty_day: { day: day, user_id: user_id, kind: kind } }

    $(document).on 'mouseenter', '.staff_calendar .calendar_day.duty>span', ->
      user = $(this).parent().data('user')
      $('.user_row[data-user='+user+']', $legend).addClass('hovered')

    $(document).on 'mouseleave', '.staff_calendar .calendar_day.duty>span', ->
      $('.user_row.hovered', $legend).removeClass('hovered')

    $('.user_wish', $legend).tooltip()

  if '#tel_info_add_list'.length > 0
    $('.tel-info__add__list__main-item').on 'click keypress', ->
      $('.tel-info__add__list__items').slideToggle(200)
      return

    $('.js--copy-number').on 'click keypress', ->
      number = $('.tel-info__add__value').text().match(/\d/g).join('')
      $temp = $('<input>')
      $('body').append $temp
      $temp.val(number).select()
      document.execCommand 'copy'
      $temp.remove()
      return

toggle_schedule_day = (el) ->
  el.toggleClass 'work_hour'

fill_schedule_hours = (cells) ->
  x = [cells[0], cells[2]]
  y = [cells[1]-1, cells[3]-1]
  $('#schedule_table>tbody>tr:eq('+y[0]+')').find('td:eq('+x[0]+')').toggleClass('work_hour')
  for row in [y[0]..y[1]]
    for col in [x[0]..x[1]]
      $('#schedule_table>tbody>tr:eq('+row+')').find('td:eq('+col+')').toggleClass('work_hour')

fill_schedule_fields = () ->
  $('tr.schedule_day','#schedule_table').each (i, row) ->
    day = $(row).attr('day')
    hours = $('td.schedule_hour.work_hour', row).map (i, hour) ->
      $(hour).attr 'hour'
    .get().join ','
    $('input.schedule_day_'+day).val hours


class CarrierWaveCropper
  constructor: ->
    $('#user_photo_cropbox').Jcrop
      aspectRatio: 1
      setSelect: [0, 0, 200, 200]
      onSelect: @update
      onChange: @update

  update: (coords) =>
    $('#user_photo_crop_x').val(coords.x)
    $('#user_photo_crop_y').val(coords.y)
    $('#user_photo_crop_w').val(coords.w)
    $('#user_photo_crop_h').val(coords.h)
    @updatePreview(coords)

  updatePreview: (coords) =>
    $('#user_photo_previewbox').css
      width: Math.round(100/coords.w * $('#user_photo_cropbox').width()) + 'px'
      height: Math.round(100/coords.h * $('#user_photo_cropbox').height()) + 'px'
      marginLeft: '-' + Math.round(100/coords.w * coords.x) + 'px'
      marginTop: '-' + Math.round(100/coords.h * coords.y) + 'px'