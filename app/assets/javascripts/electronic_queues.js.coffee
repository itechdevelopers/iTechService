jQuery ->
  if $('#select_window').length > 0
    $.getScript('/elqueue_windows/select_window')

  electronic_queues_tree('#queue_items') if $('#queue_items').length > 0

#  iPad show страница
  keyboard = null
  formatPhoneNumber = (value) ->
      digits = value.replace(/\D/g, '')
      digits = digits.replace(/^(77|78|7)/, '')

      digits = digits.slice(0, 10)

      if digits.length > 0
        "+7 (#{digits.slice(0,3)}#{if digits.length > 3 then ') ' else ''}#{digits.slice(3,6)}#{if digits.length > 6 then '-' else ''}#{digits.slice(6,8)}#{if digits.length > 8 then '-' else ''}#{digits.slice(8)}"
      else
        "+7 ("

  createKeyboard = (inputElement) ->
    keyboard = new SimpleKeyboard.default({
      onChange: (input) ->
        formattedValue = formatPhoneNumber(input)
        inputElement.value = formattedValue
        keyboard.setInput(formattedValue)

      layout: {
        default: ["1 2 3", "4 5 6", "7 8 9", "{bksp} 0 +", "{space}"]
      }

      theme: "hg-theme-default hg-layout-numeric numeric-theme"
    })
    inputElement.value = "+7 ("
    keyboard.setInput("+7 (")

  addToBreadcrumbs = (text) ->
    $('<div>', {
      class: 'queue-breadcrumbs_item',
      text: text
    }).appendTo '.queue-breadcrumbs'

  popBreadcrumbs = ->
    $('.queue-breadcrumbs .queue-breadcrumbs_item:last').remove()

  clearBreadcrumbs = ->
    $('.queue-breadcrumbs').html ''

  toggleVisibility = ->
    $('.visible').removeClass('visible').addClass('hidden')

  $(document).on 'click', '.queue-item', (event) ->
    itemId = $(this).data('item-id')
    return if $(this).data('disabled')
    title = $(this).find('h2').text()
    hasPhoneInput = $(this).data('has-phone-input')

    if $(this).data('edge')
      $(this).attr('data-disabled', true)
      sendTicketRequest(itemId)
    else
      toggleVisibility()
      $('.back-button').removeClass('hidden')
      addToBreadcrumbs(title)
      $(".queue-item[data-parent-id=#{itemId}]").removeClass('hidden').addClass('visible')
      if hasPhoneInput
        openQueueItemPhone(itemId)

  $(document).on 'click', '.create-ticket-button', ->
    itemId = $(this).closest('.queue-item-phone').data('item-id')
    if $(this).hasClass('clear-phone')
      $(this).closest('.create-ticket').find('#waiting_client_phone_number').val('')
    queueItemElement = $(".queue-item[data-item-id=#{itemId}]")
    return if queueItemElement.data('disabled')

    queueItemElement.attr('data-disabled', true)
    sendTicketRequest(itemId)

  openQueueItemPhone = (itemId) ->
    element = $(".queue-item-phone[data-item-id=#{itemId}]")
    element.removeClass('hidden').addClass('visible')
    phoneInput = element.find('#waiting_client_phone_number')
    if phoneInput.length > 0
      $('<div>', {
        class: 'simple-keyboard'
      }).insertAfter(phoneInput)

      createKeyboard(phoneInput[0])
    else
      console.error("Phone input element not found")

  destroyKeyboard = ->
    if keyboard?
      keyboard.destroy()
      keyboard = null
      $('.simple-keyboard').remove()
      $('input[type="tel"]').val('')

  $(document).on 'click', '.back-button', (event) ->
    parentId = $('.visible:first').data('parent-id')
    destroyKeyboard()
    if parentId
      toggleVisibility()
      if $(".queue-item[data-item-id=#{parentId}]").data('root')
        showRootElements()
        clearBreadcrumbs()
      else
        grandParentId = $(".queue-item[data-item-id=#{parentId}]").data('parent-id')
        $(".queue-item[data-parent-id=#{grandParentId}]").removeClass('hidden').addClass('visible')
        popBreadcrumbs()

  $(document).on 'click', '.back-to-root-button', (event) ->
    showClientTicketNumber = $('.show-client-ticket-number')
    showClientTicketNumber.find('.ticket-number').text ''
    showClientTicketNumber.addClass 'hidden'
    showRootElements()

  showRootElements = ->
    $('.back-button').addClass('hidden')
    $(".queue-item[data-root=true]").removeClass('hidden').addClass('visible')

  sendTicketRequest = (itemId) ->
    form = $(".create-ticket[data-parent-queue-item-id=#{itemId}] .create-ticket-form")
    $.ajax
      type: form.attr 'method'
      url: form.attr 'action'
      data: form.serialize()
      dataType: 'json'
      headers: { 'Accept': 'application/json' }
      beforeSend: ->
        $('.loading-indicator, .loading-overlay').removeClass('hidden')
      success: (data) ->
        $('.loading-indicator, .loading-overlay').addClass('hidden')
        toggleVisibility()
        clearBreadcrumbs()
        destroyKeyboard()
        ticketNumber = data.ticket_number
        showClientTicketNumber = $('.show-client-ticket-number')

        showClientTicketNumber.removeClass('hidden')
        showClientTicketNumber.find('.ticket-number').text ticketNumber
        $(".queue-item[data-item-id='#{itemId}'").attr('data-disabled', false)

        setTimeout (->
          if (showClientTicketNumber.find('.ticket-number').text() == data.ticket_number)
            showClientTicketNumber.find('.ticket-number').text ''
            showClientTicketNumber.addClass 'hidden'
            showRootElements()
        ), 30000

      error: (jqXHR, textStatus, errorThrown) ->
        $(".queue-item[data-item-id='#{itemId}'").attr('data-disabled', false)
        $('.loading-indicator, .loading-overlay').addClass('hidden')
        clearBreadcrumbs()
        console.log 'Error:', textStatus, errorThrown

# Управление электронной очередью
window.electronic_queues_tree = (container)->
  $.jstree._themes = "/assets/jstree/"
  $container = $(container)
  opened = $container.data('opened')
  queue_id = $container.data('electronic-queue-id')
  $container.bind("create.jstree",(e, data)->
    $.post "/electronic_queues/#{queue_id}/queue_items",
      parent_id: data.rslt.parent[0].id
      queue_item_title: data.rslt.name
    , (new_id)->
      $("li:not([id*=queue_item_])", $container).attr("id", "queue_item_#{new_id}")
  ).bind("remove.jstree",(e, data)->
    $.ajax
      type: "DELETE"
      url: "/electronic_queues/#{queue_id}/queue_items/#{data.rslt.obj[0].id.replace("queue_item_", "")}"
  ).bind("rename.jstree",(e, data)->
    $.ajax
      type: "PUT"
      url: "/electronic_queues/#{queue_id}/queue_items/#{data.rslt.obj[0].id.replace("queue_item_", "")}"
      data:
        queue_item:
          title: data.rslt.new_name
  ).bind('select_node.jstree', (e, data)->
    $container.jstree('open_node', data.rslt.obj[0])
  ).bind('move_node.jstree', (e, data)->
    moved_queue_id = data.rslt.o[0].dataset.queueItemId
    target_queue_id = data.rslt.r[0].dataset.queueItemId
    position = data.rslt.cp + 1
    $.ajax
      type: 'PUT'
      url: "/electronic_queues/#{queue_id}/queue_items/#{moved_queue_id}"
      data:
        queue_item:
          parent_id: target_queue_id,
          position: position
  ).jstree(
    core:
      strings:
        loading: "Загружаю..."
        new_node: "Новый элемент электронной очереди"
      initially_open: opened
      load_open: true
      open_parents: true
      animation: 10
    themes:
      theme: "apple"
      dots: false
      icons: false
    ui:
      select_limit: 1
    contextmenu:
      select_node: true
      items:
        create:
          label: "Создать"
          action: (obj)->
            parent_id = obj[0].id.replace("queue_item_", "")
            $.get "/electronic_queues/#{queue_id}/queue_items/new",
              queue_item:
                parent_id: parent_id
          separator_after: true
        rename:
          label: "Редактировать"
          action: (obj)->
            queue_item_id = obj[0].id.replace("queue_item_", "")
            $.get "/electronic_queues/#{queue_id}/queue_items/#{queue_item_id}/edit"
          separator_after: true
        remove:
          label: "Архивировать"
          action: (obj)->
            if confirm("Вы уверены?")
              $container.jstree('remove', obj)
    plugins: ["themes", "html_data", "ui", "crrm", "contextmenu", "dnd"]
  ).show()

# Управление талонами электронной очереди из интерфейса сотрудника
window.show_window_select_modal = ->
  $.getScript("/elqueue_windows/select_window")

$(document).on "openManageTicketsModal", () ->
  ticketLis = $('.modal-body .elqueue-ticket-container')
  if ticketLis.length
    initTicketsSortable ticketLis

initTicketsSortable = (lis) ->
  lis.each (index, element) ->
    new Sortable(element, {
      group: 'tickets',
      animation: 300,
      onEnd: (evt) =>
        saveTicketsSorting($('.modal-body .elqueue-ticket-card'), $(evt.item).data('ticket-id'))
    })

saveTicketsSorting = (lis, idMoved) ->
  ticketIds = []
  lis.each (index, li) ->
    ticketIds.push({
      'id': Number.parseInt($(li).data('ticket-id')),
      'position': index+1
    })
  $('#ticket-ids').val(JSON.stringify(ticketIds))
  $('#id-moved').val(idMoved)
  $('#form-sort-tickets').submit()
