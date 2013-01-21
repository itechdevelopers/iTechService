# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/
#= require bootstrap-datepicker

jQuery ->

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

  $('.datepicker').datepicker
    format: 'dd.mm.yyyy'
    weekStart: 1
    viewMode: 'years'
    minViewMode: 'day'

  $('td.calendar_day.work_day.empty', '#calendar.editable').click (event) ->
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

  $('.user_color_template').css 'background-color', $('#user_color').val()

  $('#user_color').colorpicker().on 'changeColor', (event)->
    $('.user_color_template').css 'background-color', event.color.toHex()

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

    $('.job_schedule_user_hours', $table)
      .live 'mouseenter', ->
        user = $(this).data 'user'
        $('.user_row[data-user='+user+']', $legend).addClass 'hovered'
      .live 'mouseleave', ->
        $('.user_row.hovered', $legend).removeClass 'hovered'

    $('.add_user_to_job_schedule', $table).click (event)->
      user = $('#staff_schedule_legend .user_row.selected').data 'user'
      unless user is undefined
        $this = $ this
        day = $this.data 'day'
        unless $('.job_schedule_user_hours[data-user='+user+'][data-day='+day+']').length > 0
          $.getScript '/users/'+user+'/add_to_job_schedule?day='+day
      event.preventDefault()

    $('.job_schedule_user_hour', $table).live 'click', (event)->
      $this = $ this
      $this.toggleClass 'work_hour'
      color = if $this.hasClass('work_hour') then $this.parents('.job_schedule_user_hours').data('color') else 'inherit'
      $this.css backgroundColor: color
      event.preventDefault()

    $('.save_job_schedule_hours').live 'click', (event)->
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

    $('.delete_job_schedule_hours').live 'click', ->
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
        data: {user: {schedule_days_attributes: {'0': {id: day_id, hours: hours}}}}
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


toggle_schedule_day = (el) ->
  el.toggleClass 'work_hour'

fill_schedule_hours = (cells) ->
  $log = $('#log')
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
