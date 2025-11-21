$(document).on 'click', '.close_product_form', ->
  $('#product_form.remote').html('')
  $('#product_form.remote').slideUp()

$(document).on 'click', '.product_selector .product_select_button', ->
  $(this).addClass('active')
  $(this).closest('.product_selector').addClass('active')

search_timeout = null
$(document).on 'keyup', '#product_choose_form #product_search_field', ->
  q = $(this).val()
  clearTimeout(search_timeout) if search_timeout?
  search_timeout = setTimeout (->
    $.get '/products.js', q: q, choose: true, form: $('#modal_form #form').val()
  ), 500

$(document).on 'keyup', '#product_choose_form #item_search_field', ->
  q = $(this).val()
  return if q.length < 2
  clearTimeout(search_timeout) if search_timeout?
  search_timeout = setTimeout (->
    $.get '/items.js',
      q: q,
      product_id: $('#selected_product').val(),
      product_group_id: $('#selected_product_group').val(),
      choose: true,
      form: $('#modal_form #form').val(),
      association: $('#modal_form #association').val()
  ), 500

$(document).on 'click', '#product_choose_form #clear_product_search_field', ->
  $('#product_choose_form #product_search_field').val('')
  $.get '/products.js', choose: true

$(document).on 'click', '#product_choose_form #clear_item_search_field', ->
  $('#product_choose_form #item_search_field').val('')

$(document).on 'click', '#product_choose_form .product_row', ->
  $form = $('#product_choose_form')
  $('#product_id', $form).removeAttr('disabled').val($(this).data('product'))
  $('#item_id', $form).attr('disabled', true)
  $form.submit()

$(document).on 'click', '#product_choose_form .item_row', ->
  $form = $('#product_choose_form')
  $('#item_id', $form).removeAttr('disabled').val($(this).data('item'))
  $form.submit()

$(document).on 'click', '#product_choose_form #add_product_item', ->
  $('#product_choose_form #selected_item').attr('disabled', true).val('')
  $('#product_choose_form #new_item_fields input').removeAttr('disabled')
  $('#product_choose_form #new_item_fields').show()
  $(this).hide()

$(document).on 'keydown', '#product_choose_form #new_item_fields input, #product_choose_form #product_search_field, #product_choose_form #item_search_field', ->
  if event.keyCode is 13
    event.preventDefault()

$(document).on 'change', '#product_form .product_option', ->
  text = $('#product_group_name, .product_option>option:selected').map(->
    $(this).text().trim()).get().join(' ')
  $('#product_name').val(text)

validation_timeout = null
$(document).on 'keyup', '#product_choose_form #new_item_fields input', ->
  clearTimeout(validation_timeout) if validation_timeout?
  validation_timeout = setTimeout (->
    is_valid = true
    $('#product_choose_form #new_item_fields input').each (i, input)->
      is_valid = false if input.value.trim() is ''
    if is_valid
      $('#product_choose_form #submit_product_button').removeAttr('disabled')
    else
      $('#product_choose_form #submit_product_button').attr('disabled', true)
  ), 500

$(document).on 'click', '.add_fields', ->
  $('.product_select_button:last').click()


$ ->
  # Функция для выбора/снятия выбора всех опций в группе
  window.selectAllInGroup = (groupId, shouldSelect) ->
    groupClass = "belongs-to-" + groupId

    # Находим все чекбоксы опций в этой группе
    $("." + groupClass).find('input[type="checkbox"]').each ->
      $checkbox = $(this)
      currentState = $checkbox.prop('checked')

      # Изменяем состояние только если оно отличается
      if currentState != shouldSelect
        $checkbox.prop('checked', shouldSelect)
        $checkbox.trigger('change')  # Триггерим событие для обновления multiselect

  # Функция для обновления состояния чекбокса группы
  window.updateGroupCheckboxState = (groupId) ->
    groupClass = "belongs-to-" + groupId
    $groupCheckbox = $("#" + groupId).find('.group-select-all-checkbox')

    return unless $groupCheckbox.length

    # Считаем выбранные опции
    $options = $("." + groupClass).find('input[type="checkbox"]')
    totalOptions = $options.length
    selectedOptions = $options.filter(':checked').length

    if selectedOptions == 0
      # Ни одна не выбрана
      $groupCheckbox.prop('checked', false)
      $groupCheckbox.prop('indeterminate', false)
    else if selectedOptions == totalOptions
      # Все выбраны
      $groupCheckbox.prop('checked', true)
      $groupCheckbox.prop('indeterminate', false)
    else
      # Частично выбраны (indeterminate state)
      $groupCheckbox.prop('checked', false)
      $groupCheckbox.prop('indeterminate', true)

  # Функция для toggle collapse/expand группы
  window.toggleCollapsibleGroup = (groupId) ->
    groupClass = "belongs-to-" + groupId
    $("." + groupClass).toggleClass('hidden')

    # Переключаем иконку стрелки
    $group = $("#" + groupId)
    $icon = $group.find('.collapse-indicator')
    if $("." + groupClass).first().hasClass('hidden')
      $icon.removeClass('fa-caret-down').addClass('fa-caret-right')
    else
      $icon.removeClass('fa-caret-right').addClass('fa-caret-down')

  window.setupMultiselectGroups = ->
    $('.multiselect-group').each (i, group) ->
      $group = $(group)

      # Пропускаем если уже обработана
      return if $group.data('setup-complete')

      $group.addClass('collapsible-group')
      $group.css('cursor', 'default')  # Отключаем pointer, т.к. будут отдельные элементы

      # Создаём чекбокс для группы
      groupCheckbox = $('<input type="checkbox" class="group-select-all-checkbox">')

      # Добавляем иконку collapse
      collapseIcon = $('<i class="fa fa-caret-down collapse-indicator"></i>')

      # Вставляем чекбокс и иконку в начало группы
      $group.prepend(collapseIcon)
      $group.prepend(groupCheckbox)

      groupId = 'multiselect-group-' + i
      $group.attr('id', groupId)

      # Связываем опции с группой
      current = $group.next()
      while current.length && !current.hasClass('multiselect-group')
        if current.hasClass('multiselect-option')
          current.addClass('belongs-to-' + groupId)
          current.addClass('hidden')
        current = current.next()

      # ОБРАБОТЧИК: Клик на чекбокс = select all в группе
      groupCheckbox.on 'click', (e) ->
        e.stopPropagation()
        isChecked = $(this).prop('checked')
        selectAllInGroup(groupId, isChecked)

      # ОБРАБОТЧИК: Клик на иконку = toggle collapse
      collapseIcon.on 'click', (e) ->
        e.stopPropagation()
        toggleCollapsibleGroup(groupId)

      # Инициализируем состояние чекбокса группы
      updateGroupCheckboxState(groupId)

      $group.data('setup-complete', true)

  window.openGroupsWithSelectedItems = ->
    # Получаем массив выбранных repair_service_ids
    selectedValues = $('.multiselect-rep-services').val() || []
    return if selectedValues.length == 0

    # Проверяем что DOM готов
    $container = $('.multiselect-container')
    return if $container.length == 0

    # Для каждой optgroup проверяем наличие выбранных опций
    $('.multiselect-rep-services optgroup').each (index, optgroup) ->
      $optgroup = $(optgroup)

      # Проверяем есть ли выбранные опции в этой группе
      hasSelected = false
      $optgroup.find('option').each ->
        if $.inArray($(this).val(), selectedValues) != -1
          hasSelected = true
          return false  # break

      # Если есть выбранные, раскрываем соответствующую группу в dropdown
      if hasSelected
        # Находим элемент .multiselect-group по ИНДЕКСУ (более надёжно чем по тексту)
        $group = $container.find('.multiselect-group').eq(index)

        if $group.length && $group.attr('id')
          groupId = $group.attr('id')
          groupClass = "belongs-to-" + groupId

          # Убираем класс hidden у всех опций в этой группе
          $("." + groupClass).removeClass('hidden')

          # Меняем иконку стрелки на "открыто"
          $group.find('.collapse-indicator')
            .removeClass('fa-caret-right')
            .addClass('fa-caret-down')

  window.handleCheckboxes = ->
    $('.select-all-checkbox').on 'change', ->
      $('.product-checkbox').prop('checked', $(this).prop('checked'))
      updateSubmitButton()

    $('.product-checkbox').on 'change', ->
      if !$(this).prop('checked')
        $('.select-all-checkbox').prop('checked', false)
      else if $('.product-checkbox:checked').length == $('.product-checkbox').length
        $('.select-all-checkbox').prop('checked', true)
      updateSubmitButton()

    $('.multiselect-rep-services-table').on 'change', ->
      updateSubmitButton()

    $('.multiselect-option').on 'click', ->
      updateSubmitButton()

    # Обработчик клика на группу больше не нужен - обработчики добавляются в setupMultiselectGroups

  updateSubmitButton = ->
    if $('.product-checkbox:checked').length > 0 && $('.multiselect-rep-services').val()?.length > 0
      $('#batch_update_submit').prop('disabled', false)
    else
      $('#batch_update_submit').prop('disabled', true)


  if $('.multiselect-rep-causes').length
    $('.multiselect-rep-causes').multiselect
      enableClickableOptGroups: true,
      nonSelectedText: 'Все причины',
      includeSelectAllOption: true,
      selectAllText: 'Все причины',
      onInitialized: ->
        $('.multiselect-rep-causes .multiselect-group, .multiselect-rep-causes .multiselect-option, .multiselect-rep-causes .multiselect-all').each ->
          $(this).attr('type', 'button')
          return
        return
      onChange: (element, checked) ->
        brands = $('.multiselect-rep-causes option:selected')
        selected = []
        $(brands).each (index, brand) ->
          selected.push [ $(this).val() ]
          return
        return

  window.initRepairServicesMultiselect = ->
    if $('.multiselect-rep-services').length
      $('.multiselect-rep-services').multiselect
        enableClickableOptGroups: false,
        nonSelectedText: 'Все виды ремонта',
        selectAllText: 'Все виды ремонта',
        onInitialized: ->
          $('.multiselect-rep-services .multiselect-group, .multiselect-rep-services .multiselect-option, .multiselect-rep-services .multiselect-all').each ->
            $(this).attr('type', 'button')
            return
          $(document).trigger('multiselect:created')
          return
        onChange: (element, checked) ->
          brands = $('.multiselect-rep-services option:selected')
          selected = []
          $(brands).each (index, brand) ->
            selected.push [ $(this).val() ]
            return

          # Обновляем состояние чекбоксов групп
          $('.multiselect-group').each ->
            groupId = $(this).attr('id')
            updateGroupCheckboxState(groupId) if groupId

          return

  window.initRepairServicesMultiselect()
  window.handleCheckboxes()

$(document).on 'ready turbolinks:load', ->
  window.initRepairServicesMultiselect()

$(document).on 'multiselect:created', ->
  window.setupMultiselectGroups()
  # Добавляем задержку для гарантии готовности DOM
  setTimeout ->
    window.openGroupsWithSelectedItems()
  , 50

$(document).on 'ajax:success', '.pagination a', ->
  window.initRepairServicesMultiselect()
  setTimeout ->
    window.handleCheckboxes()
  , 100

# Product Photos QR code handlers
$(document).on 'click', '.change-to-qr-product', (event) ->
  event.preventDefault()
  linkElement = $(this)
  idValue = linkElement.attr('id')
  productId = idValue.match(/add-photo-btn-product-(\d+)/)[1]
  $.getScript("/products/" + productId + "/show_qr")

$(document).on 'click', '.product-photo-attachments .qr_code', (event) ->
  event.preventDefault()
  $(this).addClass('hidden')
  parentElement = $(this).parent()
  linkElement = parentElement.find('a')
  linkElement.removeClass('hidden')

# Product photo gallery navigation
$(document).on 'click', '.product-photo-attachments .btn-gallery-left', (event) ->
  event.preventDefault()
  container = $(this).parent()
  chosen = container.find('.mini-chosen-one')
  photos = container.find('.mini-photo')
  currentIndex = photos.index(chosen)
  if currentIndex > 0
    chosen.removeClass('mini-chosen-one')
    $(photos[currentIndex - 1]).addClass('mini-chosen-one')

$(document).on 'click', '.product-photo-attachments .btn-gallery-right', (event) ->
  event.preventDefault()
  container = $(this).parent()
  chosen = container.find('.mini-chosen-one')
  photos = container.find('.mini-photo')
  currentIndex = photos.index(chosen)
  if currentIndex < photos.length - 1
    chosen.removeClass('mini-chosen-one')
    $(photos[currentIndex + 1]).addClass('mini-chosen-one')

