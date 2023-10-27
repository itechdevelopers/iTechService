jQuery ->

  $('a', '#object_kinds_list').click (event)->
    $('#object_kind_value').text $(this).text()
    $('#order_object_kind').val $(this).attr('object_kind')
    event.preventDefault()

  $('a', '#statuses_list').click (event)->
    $('#status_value').text $(this).text()
    $('#order_status').val $(this).attr('status')
    event.preventDefault()

  $('#order_form #client_search').keydown ->
    $('#order_customer_id').val('') if $(this).val() is ''

  $(document).on 'click', '.last_order_note', (event)->
    order_id = $(this).data('order-id')
    $(event.currentTarget).addClass('hidden')
    $('.last_order_note_full[data-order-id="' + order_id + '"').removeClass('hidden')

  $(document).on 'click', '.last_order_note_full', (event)->
    order_id = $(this).data('order-id')
    $(event.currentTarget).addClass('hidden')
    $('.last_order_note[data-order-id="' + order_id + '"').removeClass('hidden')