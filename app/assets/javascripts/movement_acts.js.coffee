jQuery ->

  # Строка, добавленная через products#select, отрисована без привязки к акту,
  # поэтому «На складе» приходит суммой по всем складам — пересчитываем по
  # выбранному складу-отправителю.
  refreshAvailableQuantity = ($rows) ->
    store_id = $('#movement_act_store_id').val()
    return unless store_id
    $rows.find('td.available_quantity').each ->
      $cell = $(this)
      item_id = $cell.siblings('td.product').find('input.item_id').val()
      return unless item_id
      $.getJSON "/items/#{item_id}/remains_in_store?store_id=#{store_id}", (data) ->
        $cell.text data.quantity

  $(document).on 'click', '#movement_act_form .add_fields, #movement_act_form .remove_fields', ->
    enumerate_table('#movement_items')

  # Делегированный обработчик: строки товаров приходят AJAX'ом из products#select
  $(document).on 'click', '.movement-act-items__code-toggle', (e) ->
    e.preventDefault()
    $(this).siblings('.movement-act-items__code').toggle()

  if $('#movement_items').length > 0
    enumerate_table('#movement_items')

  $('#movement_act_store_id').change ->
    refreshAvailableQuantity $('#movement_items tr.movement_item_fields')

  # Строку вставляет JS-ответ products#select, своего события он не шлёт —
  # ловим саму вставку в DOM
  $tbody = $('#movement_items tbody')
  if $tbody.length > 0 and window.MutationObserver
    observer = new MutationObserver (mutations) ->
      mutations.forEach (mutation) ->
        $added = $(mutation.addedNodes).filter('tr.movement_item_fields')
        refreshAvailableQuantity $added if $added.length > 0
    observer.observe $tbody[0], childList: true
