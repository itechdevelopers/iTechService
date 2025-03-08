jQuery ->
  $('#add-access-tab').tab('show')

  $('#reportsAccessTabs a').on 'click', (e) ->
    e.preventDefault()
    $(this).tab('show')

  # Обработка кнопки "Выбрать все отчеты"
  $('#select-all-reports').on 'click', ->
    $checkboxes = $('.report-checkbox')
    isAllChecked = $('.report-checkbox:checked').length == $checkboxes.length
    
    $checkboxes.prop('checked', !isAllChecked)
    
    # Меняем текст кнопки в зависимости от состояния
    if !isAllChecked
      $(this).text('Отменить все')
    else
      $(this).text('Выбрать все')

  $('#select-all-reports-remove').on 'click', ->
    $checkboxes = $('.report-checkbox-remove')
    isAllChecked = $('.report-checkbox-remove:checked').length == $checkboxes.length
    
    $checkboxes.prop('checked', !isAllChecked)
    
    if !isAllChecked
      $(this).text('Отменить все')
    else
      $(this).text('Выбрать все')

  $('.user-search-input-remove').on 'keyup', ->
    searchTerm = $(this).val().toLowerCase()
    
    if searchTerm.length > 0
      $('.user-item-remove').each ->
        searchableText = $(this).find('label').data('searchable')
        if searchableText.indexOf(searchTerm) > -1
          $(this).show()
        else
          $(this).hide()
    else
      $('.user-item-remove').show()
  
  # Поиск пользователей
  $('.user-search-input').on 'keyup', ->
    searchTerm = $(this).val().toLowerCase()
    
    if searchTerm.length > 0
      $('.user-item').each ->
        searchableText = $(this).find('label').data('searchable')
        if searchableText.indexOf(searchTerm) > -1
          $(this).show()
        else
          $(this).hide()
    else
      $('.user-item').show()

  #  Аннотации к отчетам
  $annotationBtn = $('.reports-annotation-btn')

  $annotationBtn.on 'click', (e) ->
    e.preventDefault()
    currentText = $annotationBtn.text().trim()

    if currentText == 'Редактировать аннотации'
      $annotationBtn.text('Закончить редактирование')
      $('.report-annotation-form').css('display', 'block')
    else
      $annotationBtn.text('Редактировать аннотации')
      $('.report-annotation-form').css('display', 'none')
      $('.annotation-form-container').css('display', 'none')

  $('.report-annotation-form').on 'click', (e) ->
    e.preventDefault()
    $formContainer = $(this).siblings('.annotation-form-container')

    if $formContainer.is(':visible')
      $formContainer.hide()
    else
      $formContainer.show()

  hoverTimeout = null
  tooltip = $('<div class="report-annotation"></div>').appendTo('body').hide()

  $('.report_col-card, .report_column-card').hover(
    (e) ->
      clearTimeout(hoverTimeout)
      $card = $(this)
      annotation = $card.attr('data-annotation')

      if annotation && annotation.trim() != ''
        hoverTimeout = setTimeout( ->
          tooltipText = annotation
          posX = e.pageX
          posY = e.pageY + 20

          tooltip.text(tooltipText)
            .css({
            top: posY + 'px',
            left: posX + 'px'
          })
            .fadeIn(200)
        , 500)  # Задержка в 500 мс перед показом тултипа
  , ->
      clearTimeout(hoverTimeout)
      tooltip.fadeOut(200)
  )

  $('.report_col-card, .report_column-card').mousemove (e) ->
    tooltip.css({
      top: (e.pageY + 20) + 'px',
      left: e.pageX + 'px'
    })

  #
  if $('#report_form .multiselect').length
    $('#report_form .multiselect').multiselect
      enableClickableOptGroups: true,
      nonSelectedText: 'Подразделения',
      includeSelectAllOption: true,
      selectAllText: 'Все подразделения',
      allSelectedText: 'Все подразделения',
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

  if $('#report_form .multiselect-sp').length
    $('#report_form .multiselect-sp').multiselect
      enableCollapsibleOptGroups: true,
      collapseOptGroupsByDefault: true,
      nonSelectedText: 'Запчасти',
      onInitialized: ->
        $('#report_form .multiselect-group, #report_form .multiselect-option, #report_form .multiselect-all').each ->
          $(this).attr('type', 'button')
      onChange: (element, checked) ->
        brands = $('#report_form .multiselect-sp option:selected')
        selected = []
        $(brands).each (index, brand) ->
          selected.push [ $(this).val() ]

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

$(document).on 'click', '#accuracy_checkbox', ->
  $('pre.pre-unformatted.hidden')
    .removeClass('hidden')
    .siblings()
    .addClass('hidden')

$(document).on 'click', '#report_result .toggle_depth', ->
  depth = Number $(this).data('depth')
  $table = $('#report_result table')
  $('.detailable[data-depth=' + depth - 1 + ']')
  return

$(document).ready () ->
  reportsBoardUls = $('.reports_board .report_col')
  if reportsBoardUls.length
    initReportsSortable reportsBoardUls

initReportsSortable = (uls) ->
  saveReportsBinded = saveReportsBoard.bind(null, uls)
  uls.each (index, element) ->
    new Sortable(element, { group: 'reports', animation: 300, onEnd: () => saveReportsBoard($('.reports_board .report_col')) })

saveReportsBoard = (uls) ->
  reportsIds = { 'columns': [] }
  uls.each (index, ul) ->
    colIds = []
    $(ul).find('.report_col-card').each (i, card) ->
      colIds.push(Number.parseInt($(card).data('card-id')))
    reportsIds.columns.push({
      'id': Number.parseInt($(ul).data('col-id')),
      'colIds': colIds
    })
  boardId = $('.reports_board').data('id')
  $('#board-ids').val(JSON.stringify(reportsIds))
  $('#form-reports-board').submit()
