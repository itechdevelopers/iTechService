$(document).on 'change', '#locations_department_filter', ->
  selected = $(this).val()
  rows = $('#locations_table tbody tr')

  if !selected || selected.length == 0
    rows.show()
  else
    rows.each ->
      dept = $(this).data('department')
      if $.inArray(dept, selected) != -1
        $(this).show()
      else
        $(this).hide()

$(document).on 'click', '#locations_filter_reset', ->
  $('#locations_department_filter').val([])
  $('#locations_table tbody tr').show()

$(document).on 'click', '.locations-sortable', ->
  $th = $(this)
  table = $('#locations_table')
  tbody = table.find('tbody')
  rows = tbody.find('tr').toArray()

  currentDir = $th.data('sort-dir') || 'none'

  if currentDir == 'asc'
    newDir = 'desc'
  else
    newDir = 'asc'

  $th.data('sort-dir', newDir)

  rows.sort (a, b) ->
    deptA = $(a).data('department') || ''
    deptB = $(b).data('department') || ''
    comparison = deptA.localeCompare(deptB, 'ru')
    if newDir == 'desc' then -comparison else comparison

  $.each rows, (index, row) ->
    tbody.append(row)

  if newDir == 'asc'
    $th.html($th.html().replace(/▲▼|▼▲|▲|▼/, '▲'))
  else
    $th.html($th.html().replace(/▲▼|▼▲|▲|▼/, '▼'))
