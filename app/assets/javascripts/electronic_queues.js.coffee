jQuery ->
  electronic_queues_tree('#queue_items') if $('#queue_items').length > 0

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
