# Drag-and-drop для перемещения видов ремонта (<tr>) между группами (<li> в jsTree).
# Работает поверх нативного HTML5 DnD, чтобы не конфликтовать с mousedown-based DnD jsTree.

DATA_KEY = 'text/repair-service-id'

jQuery ->
  $(document).on 'dragstart', '.rs-draggable', (e) ->
    id = $(this).data('repair-service-id')
    return unless id
    e.originalEvent.dataTransfer.setData(DATA_KEY, String(id))
    e.originalEvent.dataTransfer.effectAllowed = 'move'
    $(this).addClass('rs-dragging')

  $(document).on 'dragend', '.rs-draggable', ->
    $(this).removeClass('rs-dragging')
    $('.rs-drop-target').removeClass('rs-drop-target')

  # jsTree оборачивает текст ссылки в <a>, поэтому dragover/drop ловим на <li>,
  # но проверяем, что источник — наш ряд (dataTransfer.types содержит наш ключ).
  # types в Chromium — DOMStringList, поэтому всегда приводим к массиву.
  isRepairServiceDrag = (e) ->
    raw_types = e.originalEvent.dataTransfer?.types or []
    Array.from(raw_types).indexOf(DATA_KEY) >= 0

  # stopPropagation важен: дерево групп вложенное (<li> внутри <li>),
  # без него bubble перекрашивает все родительские li и подсвечивается
  # не тот, на который реально навели.
  $(document).on 'dragover', '#repair_groups li.repair_group', (e) ->
    return unless isRepairServiceDrag(e)
    e.preventDefault()
    e.stopPropagation()
    e.originalEvent.dataTransfer.dropEffect = 'move'
    $('.rs-drop-target').removeClass('rs-drop-target')
    $(this).addClass('rs-drop-target')

  $(document).on 'drop', '#repair_groups li.repair_group', (e) ->
    return unless isRepairServiceDrag(e)
    e.preventDefault()
    e.stopPropagation()  # чтобы jsTree dnd не обработал событие как свой move_node

    service_id = e.originalEvent.dataTransfer.getData(DATA_KEY)
    group_id = $(this).data('repair-group-id')
    $('.rs-drop-target').removeClass('rs-drop-target')
    return unless service_id and group_id

    # No-op: drop на ту же группу, в которой вид уже лежит.
    # params[:group] текущей страницы хранится в скрытом поле #group-param формы поиска.
    current_group = $('#group-param').val()
    if current_group and String(current_group) is String(group_id)
      return

    csrf_token = $('meta[name="csrf-token"]').attr('content')
    $.ajax
      type: 'PATCH'
      url: "/repair_services/#{service_id}/move"
      headers: { 'X-CSRF-Token': csrf_token }
      data: { repair_group_id: group_id }
      dataType: 'json'
      success: (resp) ->
        showRepairServiceMessage "Вид ремонта перенесён в группу «#{resp.repair_group_name}»", 'success'
        # Перезагрузить таблицу текущей группы, чтобы переехавший ряд исчез
        $('#search_form').trigger('submit.rails')
      error: (xhr) ->
        msg = xhr.responseJSON?.errors?.join('; ') or 'Ошибка при перемещении вида ремонта'
        showRepairServiceMessage msg, 'error'

  showRepairServiceMessage = (text, kind) ->
    cls = if kind is 'success' then 'alert-success' else 'alert-error'
    icon = if kind is 'success' then 'icon-ok-sign' else 'icon-exclamation-sign'
    $('#repair_groups_messages').html """
      <div class="row">
        <div class="span6 alert_place">
          <div class="alert #{cls}">
            <a class="close" data-dismiss="alert" onclick="$(this).parents('.row:first').remove()">&times;</a>
            <i class="#{icon}"></i> <span class="text">#{text}</span>
          </div>
        </div>
      </div>
    """
    if kind is 'success'
      setTimeout (-> $('#repair_groups_messages .row').fadeOut(300, -> $(this).remove())), 3000
