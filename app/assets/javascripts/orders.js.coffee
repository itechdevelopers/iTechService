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
            if response.kind != ''
              kind_text = $('#object_kinds_list a[object_kind="' + response.kind + '"]').text()
              $('#object_kind_value').text(kind_text)
              $('#order_object_kind').val(response.kind)
            if response.price != ''
              $('#order_approximate_price').val(response.price)
            
            # Display stock information with colors
            if response.stores && response.stores.length > 0
              # Fetch department colors first
              $.get '/products/department_colors', (colorMapping) ->
                stockInfo = '<strong>Наличие на складах:</strong><br><br>'
                
                # Group stores by department for spacing
                departmentGroups = {}
                for store in response.stores
                  dept_code = store.department_code
                  departmentGroups[dept_code] ||= []
                  departmentGroups[dept_code].push(store)
                
                # Display each department group with spacing
                for dept_code, stores of departmentGroups
                  for store in stores
                    color = colorMapping[store.department_code] || '#f0f0f0'
                    textColor = if window.App?.utils?.getContrastColor then App.utils.getContrastColor(color) else '#000000'
                    stockInfo += "<span class='stock-line' style='background-color: #{color}; color: #{textColor}; padding: 2px 6px; border-radius: 3px; display: inline-block; margin: 2px 0;'>#{store.name} (#{store.department_code}) - В наличии: #{store.quantity} шт., В резерве: #{store.reserve} шт.</span><br>"
                  stockInfo += '<br>' # Add space between departments
                
                $('#article_not_found').html(stockInfo)
            else
              $('#article_not_found').html('<em>Нет информации о наличии на складах</em>')
          else if response.status == 'not_found'
            $('#order_object').val('')
            $('#article_not_found').text('Ошибка при поиске по артикулу в 1С')

        error: ->
          $('#article_not_found').text('')
          console.log('Произошла ошибка при выполнении запроса')
    else
      # Clear all fields when article is emptied
      $('#order_object').val('')
      $('#order_object_url').val('')
      $('#article_not_found').text('')
      $('#object_kind_value').text('')
      $('#order_object_kind').val('')
      $('#order_approximate_price').val('')
