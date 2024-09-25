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

  $('#product_article').on 'input', ->
    article = $(this).val().trim()
    if article != ''
      $.ajax
        url: '/products/product_by_article'
        method: 'GET'
        data: { article: article }
        dataType: 'json'
        success: (response) ->
          if response.status == 'found'
            $('#order_object').val(response.name)
            $('#article_not_found').text('')
            if response.kind != ''
              kind_text = $('#object_kinds_list a[object_kind="' + response.kind + '"]').text()
              $('#object_kind_value').text(kind_text)
              $('#order_object_kind').val(response.kind)
          else if response.status == 'not_found'
            $('#order_object').val('')
            $('#article_not_found').text('В базе Айса не найдено')
        error: ->
          console.log('Произошла ошибка при выполнении запроса')