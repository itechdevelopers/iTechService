jQuery ->
  if $('#select_window').length > 0
    $.getScript('/elqueue_windows/select_window')

  electronic_queues_tree('#queue_items') if $('#queue_items').length > 0

#  iPad show страница
  toggleVisibility = ->
    $('.visible').removeClass('visible').addClass('hidden')

  $(document).on 'click', '.queue-item', (event) ->
    itemId = $(this).data('item-id')

    if $(this).data('edge')
      sendTicketRequest(itemId)
    else
      toggleVisibility()
      $('.back-button').removeClass('hidden')
      $(".queue-item[data-parent-id=#{itemId}]").removeClass('hidden').addClass('visible')

  $(document).on 'click', '.back-button', (event) ->
    parentId = $('.visible:first').data('parent-id')
    if parentId
      toggleVisibility()
      if $(".queue-item[data-item-id=#{parentId}]").data('root')
        showRootElements()
      else
        grandParentId = $(".queue-item[data-item-id=#{parentId}]").data('parent-id')
        $(".queue-item[data-parent-id=#{grandParentId}]").removeClass('hidden').addClass('visible')

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
      success: (data) ->
        toggleVisibility()
        ticketNumber = data.ticket_number
        showClientTicketNumber = $('.show-client-ticket-number')

        showClientTicketNumber.removeClass('hidden')
        showClientTicketNumber.find('.ticket-number').text ticketNumber

        setTimeout (->
          showClientTicketNumber.find('.ticket-number').text ''
          showClientTicketNumber.addClass 'hidden'
          showRootElements()
        ), 10000

      error: (jqXHR, textStatus, errorThrown) ->
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
          label: "Удалить"
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
    new Sortable(element, { group: 'tickets', animation: 300, onEnd: () => saveTicketsSorting($('.modal-body .elqueue-ticket-card')) })

saveTicketsSorting = (lis) ->
  ticketIds = []
  lis.each (index, li) ->
    ticketIds.push({
      'id': Number.parseInt($(li).data('ticket-id')),
      'position': index+1
    })
  $('#ticket-ids').val(JSON.stringify(ticketIds))
  $('#form-sort-tickets').submit()
