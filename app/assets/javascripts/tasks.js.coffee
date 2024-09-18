$ ->
  window.initTasksSortable = (list) ->
    list.each (i, element) ->
      new Sortable(element, {
        group: 'tasks',
        animation: 300,
        onEnd: (e) =>
          saveTasksSorting($('.tasks-body tr'))
      })

  window.saveTasksSorting = (newList) ->
    tasksIds = []
    newList.each (i, tr) ->
      tasksIds.push({
        'id': Number.parseInt($(tr).find('td:first').text().trim()),
        'position': i+1
      })
    $('#tasks_positions').val(JSON.stringify(tasksIds))
    $('#update-positions-form').submit()