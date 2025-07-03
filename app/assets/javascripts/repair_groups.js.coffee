jQuery ->

  repair_groups_tree('#repair_groups') if $('#repair_groups.editable').length > 0
  repair_groups_tree_readonly('#repair_groups') if $('#repair_groups.readonly').length > 0

window.repair_groups_tree = (container)->
  $.jstree._themes = "/assets/jstree/"
  $container = $(container)
  root_id = $container.data('root_id')
  group_id = $container.data('repair_group_id')
  opened = $container.data('opened')
  $container.bind("create.jstree",(e, data)->
    $.post "/repair_groups/",
      parent_id: data.rslt.parent[0].id
      repair_group_name: data.rslt.name
    , (new_id)->
      $("li:not([id*=repair_group_])", $container).attr("id", "repair_group_#{new_id}")
  ).bind("remove.jstree",(e, data)->
    $.ajax
      type: "DELETE"
      url: "/repair_groups/#{data.rslt.obj[0].id.replace("repair_group_", "")}"
      dataType: "json"
      success: (response)->
        # Tree node removal is handled by jstree automatically on successful AJAX
      error: (xhr, status, error)->
        # Parse error response and show user-friendly message
        errorMessage = "Произошла ошибка при удалении группы ремонта."
        if xhr.responseJSON && xhr.responseJSON.errors
          errorMessage = xhr.responseJSON.errors.join("; ")
        
        # Display error message using the same pattern as destroy.js.erb
        $('#repair_groups_messages').html(
          '<div class="row">' +
          '<div class="span6 alert_place">' +
          '<div class="alert alert-error">' +
          '<a class="close" data-dismiss="alert" onclick="$(this).parents(\'.row:first\').remove()">&times;</a>' +
          '<i class="icon-exclamation-sign"></i> ' +
          '<span class="text">' + errorMessage + '</span>' +
          '</div>' +
          '</div>' +
          '</div>'
        )
        
        # Refresh the tree to restore the node that was optimistically removed
        $(e.currentTarget).jstree("refresh")
  ).bind("rename.jstree",(e, data)->
    $.ajax
      type: "PUT"
      url: "/repair_groups/#{data.rslt.obj[0].id.replace("repair_group_", "")}"
      data:
        repair_group:
          name: data.rslt.new_name
  ).bind('select_node.jstree', (e, data)->
    $container.jstree('open_node', data.rslt.obj[0])
  ).bind('move_node.jstree', (e, data)->
    moved_group_id = data.rslt.o[0].dataset.repairGroupId
    if data.rslt.np[0].dataset.repairGroupId?
      target_group_id = data.rslt.r[0].dataset.repairGroupId
    else
      target_group_id = 'nil'
    $.ajax
      type: 'PUT'
      url: "/repair_groups/#{moved_group_id}"
      data:
        repair_group:
          parent_id: target_group_id
  ).jstree(
    core:
      strings:
        loading: "Загружаю..."
        new_node: "Новая Группа"
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
#    dnd:
#      drop_finish: ->
#        json_data:
#          ajax:
#            url: "/repair_groups/#{root_id}.json"
#            data: (n)->
#              id: (if n.attr then n.attr("id") else 0)
    contextmenu:
      select_node: true
      items:
        create:
          label: "Создать"
          action: (obj)->
            group_id = obj[0].id.replace("repair_group_", "")
            $.get "/repair_groups/new.js", {repair_group: {parent_id: group_id}}
          separator_after: true
        edit:
          label: "Редактировать"
          action: (obj)->
            group_id = obj[0].id.replace("repair_group_", "")
            $.get "/repair_groups/#{group_id}/edit.js"
        rename:
          label: "Переименовать"
          action: (obj)->
            @rename obj
          separator_after: true
        remove:
          label: "Удалить"
          action: (obj)->
            if confirm("Вы уверены?")
              if @is_selected(obj)
                @remove()
              else
                @remove obj
    plugins: ["themes", "html_data", "ui", "contextmenu", "crrm", "dnd"]
  ).show()

window.repair_groups_tree_readonly = (container)->
  $.jstree._themes = "/assets/jstree/"
  $container = $(container)
  root_id = $container.data('root_id')
  $container.bind('select_node.jstree', (e, data)->
    $container.jstree('open_node', data.rslt.obj[0])
  ).jstree(
    core:
      strings:
        loading: "Загружаю..."
      load_open: true
      open_parents: true
      animation: 10
    themes:
      theme: "apple"
      dots: false
      icons: false
    ui:
      select_limit: 1
    plugins: ["themes", "html_data", "ui"]
  ).show()