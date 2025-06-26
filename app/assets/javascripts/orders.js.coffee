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

  $(document).on 'click', '#statuses_list a', (e) ->
    status = $('#order_status').val()
    if status == 'archive'
      $('#archival_features').removeClass('hidden')
    else
      $('#archival_features').addClass('hidden')

  $('#order_article').on 'input', ->
    article = $(this).val().trim()
    if article != ''
      $('#order_object_url').val("http://itechstore.ru/api/v1/redirects/product-by-sku/#{article}/")
      department_id = $('#order_department_id').val()
      $.ajax
        url: '/products/product_by_article'
        method: 'GET'
        data: { article: article, department_id: department_id }
        dataType: 'json'
        success: (response) ->
          if response.status == 'found'
            $('#order_object').val(response.name)
            $('#article_not_found').text('')
            if response.kind != ''
              kind_text = $('#object_kinds_list a[object_kind="' + response.kind + '"]').text()
              $('#object_kind_value').text(kind_text)
              $('#order_object_kind').val(response.kind)
            if response.price != ''
              $('#order_approximate_price').val(response.price)
            if response.stores && response.stores.length > 0
              $('#order_source_store_id option').each ->
                store_id = $(this).val()
                store_name = $(this).text().split(' - ')[0]
                if store_id != '' && store_id != null
                  $(this).text("#{store_name} - нет информации о количестве на складе")

              for store in response.stores
                option = $("#order_source_store_id option[value='#{store.id}']")
                if option.length > 0
                  store_name = option.text().split(' - ')[0]
                  option.text("#{store_name} - #{store.quantity} шт.")
          else if response.status == 'not_found'
            $('#order_object').val('')
            $('#article_not_found').text('Ошибка при поиске по артикулу в 1С')

            $('#order_source_store_id option').each ->
              store_id = $(this).val()
              if store_id != '' && store_id != null
                store_name = $(this).text().split(' - ')[0]
                $(this).text("#{store_name} - нет информации о количестве на складе")
        error: ->
          console.log('Произошла ошибка при выполнении запроса')
