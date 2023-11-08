jQuery ->

  if $('#report_form .multiselect').length
    $('#report_form .multiselect').multiselect
      enableClickableOptGroups: true,
      nonSelectedText: 'Все подразделения',
      includeSelectAllOption: true,
      selectAllText: 'Все подразделения',
      onInitialized: ->
        $('#report_form .multiselect-group, #report_form .multiselect-option, #report_form .multiselect-all').each ->
          $(this).attr('type', 'button')
          return
        return
      onChange: (element, checked) ->
        brands = $('#report_form .multiselect option:selected')
        selected = []
        $(brands).each (index, brand) ->
          selected.push [ $(this).val() ]
          return
        return

  if $('#report_form .multiselect-pr-groups').length
    $('#report_form .multiselect-pr-groups').multiselect
      enableClickableOptGroups: true,
      nonSelectedText: 'Все группы девайсов',
      includeSelectAllOption: true,
      selectAllText: 'Все группы девайсов',
      onInitialized: ->
        $('#report_form .multiselect-group, #report_form .multiselect-option, #report_form .multiselect-all').each ->
          $(this).attr('type', 'button')
          return
        return
      onChange: (element, checked) ->
        brands = $('#report_form .multiselect-pr-groups option:selected')
        selected = []
        $(brands).each (index, brand) ->
          selected.push [ $(this).val() ]
          return
        return

  if $('#report_form .multiselect-tasks').length
    $('#report_form .multiselect-tasks').multiselect
      enableClickableOptGroups: true,
      nonSelectedText: 'Все задачи',
      includeSelectAllOption: true,
      selectAllText: 'Все задачи',
      onInitialized: ->
        $('#report_form .multiselect-group, #report_form .multiselect-option, #report_form .multiselect-all').each ->
          $(this).attr('type', 'button')
          return
        return
      onChange: (element, checked) ->
        brands = $('#report_form .multiselect-tasks option:selected')
        selected = []
        $(brands).each (index, brand) ->
          selected.push [ $(this).val() ]
          return
        return

  $('#report_name').change ->
    if $(this).val() == 'remnants'
      $('#report_store_id').show()
    else
      $('#report_store_id').hide()

$(document).on 'click', '.report_task_details', ->
  $task_row = $(this).parents('.task_row')
  $task_row.nextUntil('.task_row').slideToggle()
  false

$(document).on 'click', '#report_result .detailable>td', ->
  $row = $(this).closest('tr')
  depth = Number($row.data('depth'))
  if depth >= 0
    if $row.hasClass 'open'
      $row.nextAll('.details').each ->
        this_depth = Number($(this).data('depth'))
        if this_depth > depth
          $(this).removeClass('open').hide()
        else
          return false
      $row.removeClass('open')
    else
      $row.nextAll('.details').each ->
        this_depth = Number($(this).data('depth'))
        $(this).show() if this_depth == depth+1
        if this_depth <= depth
          return false
      $row.addClass('open')
  else
    $row.nextUntil('.detailable').toggle()

  return

$(document).on 'click', '#report_result .toggle_depth', ->
  depth = Number $(this).data('depth')
  $table = $('#report_result table')
  $('.detailable[data-depth=' + depth - 1 + ']')
  return