jQuery ->

  $service_job_form = $('form.service_job_form')

  $('.service_job_comment_tooltip').tooltip()

  $('.service_job_progress').tooltip
    placement: 'left'
    html: true

  if $service_job_form.length > 0
    $service_job_form.find('label.important').tooltip(title: 'Информация, которая заполняется здесь, отображается в заказ-наряде. Будьте внимательны.')

    $(document).on 'click', '.device_task_task .custom-option', () ->
      task_id = $(this).data('value')
      task_code = $(this).data('code')
      task_name = $(this).text().trim()
      $row = $(this).parents('.device_task')
      $extendedRow = $row.next('.task-extended-row')
      task_cost = $row.find('.device_task_cost')
      is_change_location = $row.is(':first-child')
      item_id = $('#service_job_item_id').val()
      department_id = $('[name="service_job[department_id]"]:checked').val()

      # Update data attribute on row
      $row.attr('data-task-code', task_code)

      $.getJSON "/tasks/#{task_id}.json", {department_id: department_id}, (data)->
        task_cost.val data.cost

        if is_change_location
          $('#location_id').val(data.location_id)
          $('#location_value').text(data.location_name)

        if data['is_repair?']
          notifyCheckbox = document.getElementById('service_job_notify_client')
          notifyCheckbox.checked = true if notifyCheckbox

        # Show extended block for "Ремонт" task
        if task_code == 'repair' || task_name == 'Ремонт'
          showRepairSelection($extendedRow)
        else
          hideRepairSelection($extendedRow)

      $.getJSON "/tasks/#{task_id}/device_validation", {item_id: item_id}, (data)->
        alert(data['message']) if data['message']

    $(document).on 'focus', '.device_task_comment', ->
      $(this).popover(trigger: 'focus', placement: 'top', html: true)

#    $(document).on 'change', '.device_task:first-child .device_task_task', ->
#      task_id = $(this).val()
#      unless task_id is ''
#        $.getJSON "/tasks/#{task_id}.json", (data)->
#          $field = $('#location_id')
#          if $field.find("[value='#{data.location_id}']").length == 0
#            $field.append "<option value='#{data.location_id}'>#{data.location_name}</option>"
#          $field.val(data.location_id)


    $(document).on 'click', '.security-code-option', (e) ->
      e.preventDefault()
      value = $(this).data('value')
      inputField = $(this).closest('.input-append').find('input')
      inputField.val(value)

      button = $(this).closest('.btn-group').find('.dropdown-toggle')
      button.text($(this).text())

      # Auto-populate client_comment when any "no password" option selected (v2 only)
      if value in ['none', 'not_provided', 'not_known']
        $form = $(this).closest('form.service_job_form')
        if $form.data('form-version') == 'v2'
          $clientComment = $form.find('#service_job_client_comment')
          if $clientComment.length > 0
            commentText = 'Ввиду отсутствия пароля проверить работоспособность всех функций не предоставляется возможным'
            $clientComment.val(commentText)

    $('#service_job_contact_phone_none').click (event)->
      $('#service_job_contact_phone').val '-'
      event.preventDefault()

    $('#service_job_contact_phone_copy').click (event)->
      client_phone = $('#client_search').val().split('/')[1].match(/[0-9]/g).join('')
      $('#service_job_contact_phone').val client_phone
      event.preventDefault()

    $fields_with_templates = $service_job_form.find('.has-templates')

    $fields_with_templates.focus ->
      $(this).popover('show')

    $fields_with_templates.blur ->
      $(this).popover('hide')

    $(document).on 'click', '.service-job_template', ->
      content = this.innerText
      $input = $(this).closest('.controls').find('.has-templates')
      old_value = $input.val()
      new_value = old_value + ' ' + content
      $input.val(new_value.trim())

#  $('#service_job_imei').blur ()->
#    $.getJSON '/service_jobs/check_imei?imei_q='+$(this).val(), (data)->
#      if data.present
#        $('#service_job_imei').parents('.control-group').addClass 'warning'
#        if $('#service_job_imei').siblings('.help-inline').length
#          $('#service_job_imei').siblings('.help-inline').html data.msg
#        else
#          $('#service_job_imei').parents('.controls').append "<span class='help-inline'>"+data.msg+"</span>"
#      else
#        $('#service_job_imei').parents('.control-group').removeClass 'warning'
#        $('#service_job_imei').siblings('.help-inline').remove()

  $('#service_job_imei_search, #service_job_serial_number_search').click ()->
    $this = $(this)
    val = $this.prev('input').val()
    if val isnt ''
      $.getJSON '/imported_sales?search='+val, (res)->
        info_tag = "<span class='help-inline imported_sales_info'>"
        if res.length > 0
          for r in res
            d = new Date(r.sold_at)
            info_tag += '[' + d.toLocaleDateString() + ': ' + r.quantity + '] '
        else
          info_tag += res.message
        info_tag += "</span>"
        $this.parent().siblings('.imported_sales_info').remove()
        $this.parent().after info_tag
      $.getJSON '/items?saleinfo=1&q=' + val, (res)->
        $this.parent().siblings('.sales_info').remove()
        if res.id
          if res.sale_info
            info_s = res.sale_info
          else
            info_s = '-'
        else
          info_s = res.message
        $this.parent().after "<span class='help-inline sales_info'>#{info_s}</span>"

  $('#new_service_job_popup').mouseleave ->
    setTimeout (->
      $('#new_service_job_popup').fadeOut()
    ), 1000

  $('#check_imei_link').click ->
    imei = $(this).parent().find('input').val()
    this.setAttribute('href', "http://iunlocker.net/check_imei.php?imei=#{imei}")

  $('.change-to-qr').on 'click', (event) ->
    event.preventDefault()
    linkElement = $(this)
    idValue = linkElement.attr('id')
    divisionValue = idValue.match(/add-photo-btn-(\w+)-(\d+)/)[1]
    serviceJobValue = idValue.match(/add-photo-btn-(\w+)-(\d+)/)[2]
    $.getScript("/service_jobs/" + serviceJobValue + "/show_qr?division=" + divisionValue)

  $(document).on 'click', '.qr_code', (event) ->
    event.preventDefault()
    $(this).addClass('hidden')
    parentElement = $(this).parent()
    linkElement = parentElement.find('a')
    linkElement.removeClass('hidden')

  $(document).on 'click', '#gallery-container', (event) ->
    clicked_left = $(event.target).is('.btn-gallery-left')
    clicked_right = $(event.target).is('.btn-gallery-right')
    return if !clicked_left && !clicked_right
    photos = $('.gallery .photo').toArray()
    chosen_photo_index = photos.findIndex (photo) ->
      $(photo).hasClass('chosen')
    if chosen_photo_index == 0 && clicked_left
      next_photo_index = photos.length - 1
    else if chosen_photo_index == photos.length - 1 && clicked_right
      next_photo_index = 0
    else if clicked_left
      next_photo_index = chosen_photo_index - 1
    else if clicked_right
      next_photo_index = chosen_photo_index + 1
    $(photos[chosen_photo_index]).removeClass('chosen')
    $(photos[next_photo_index]).addClass('chosen')

  $(document).on 'click', '.photo-gallery-mini', (event) ->
    clickedElement = $(event.currentTarget)
    divisionValue = clickedElement.attr('data-division')
    console.log(divisionValue)
    clicked_left = $(event.target).is('.btn-gallery-left[data-division="' + divisionValue + '"]')
    clicked_right = $(event.target).is('.btn-gallery-right[data-division="' + divisionValue + '"]')
    return if !clicked_left && !clicked_right
    photos = $('.photo-gallery-mini .mini-photo[data-division="' + divisionValue + '"]').toArray()
    first_chosen_index = photos.findIndex (photo) ->
      $(photo).hasClass('mini-chosen-one')
    last_chosen_index = photos.findIndex (photo) ->
      $(photo).hasClass('mini-chosen-two')
    if first_chosen_index == 0 && clicked_left
      next_first_chosen_index = photos.length - 1
      next_last_chosen_index = first_chosen_index
    else if last_chosen_index == photos.length - 1 && clicked_right
      next_last_chosen_index = 0
      next_first_chosen_index = last_chosen_index
    else if clicked_left
      next_first_chosen_index = first_chosen_index - 1
      next_last_chosen_index = first_chosen_index
    else if clicked_right
      next_first_chosen_index = last_chosen_index
      next_last_chosen_index = last_chosen_index + 1
    $(photos[first_chosen_index]).removeClass('mini-chosen-one')
    $(photos[last_chosen_index]).removeClass('mini-chosen-two')
    $(photos[next_first_chosen_index]).addClass('mini-chosen-one')
    $(photos[next_last_chosen_index]).addClass('mini-chosen-two')

$(document).on 'click', '#service_job_client_notified_false',  (event)->
  service_job_id = document.getElementById('service_job_form').action.match(/\d+$/)[0]
  $.getScript("/service/sms_notifications/new?service_job_id=#{service_job_id}")

$(document).on 'click', '.returning_device_tooltip', ->
  $(this).tooltip()
  $(this).tooltip('toggle')

$(document).on 'click', '#completion_act_link', ->
  $('#service_job_archive_button').removeClass('hidden')

#TODO implement via cable
#PrivatePub.subscribe '/service_jobs/new', (data, channel)->
#  if data.service_jobs.location_id == $('#profile_link').data('location')
#    $('#new_service_job_popup').fadeIn()
#TODO implement via cable
#PrivatePub.subscribe '/service_jobs/returning_alert', (data, channel)->
#  $.getScript '/announcements/'+data.announcement_id

# ========== Repair Selection Functions (Cascading) ==========

# Show repair selection form and load cause groups
window.showRepairSelection = ($extendedRow) ->
  $content = $extendedRow.find('.repair-selection')

  # Dynamically get item_id from form
  item_id = $('#service_job_item_id').val()

  unless item_id
    alert('Сначала выберите устройство')
    return

  # Get product_id via AJAX
  $.getJSON "/items/#{item_id}.json", (item_data) ->
    product_id = item_data.product_id
    department_id = $('[name="service_job[department_id]"]:checked').val()

    unless product_id
      alert('У выбранного устройства не указан продукт')
      return

    # Store product_id and department_id for subsequent requests
    $content.data('product-id', product_id)
    $content.data('department-id', department_id)

    # Load repair cause groups for product
    $.getJSON "/repair_causes/for_product/#{product_id}", (groups) ->
      $select = $content.find('.repair-cause-group-select')
      $select.html('<option value="">Выберите категорию</option>')

      $.each groups, (i, group) ->
        $select.append("<option value='#{group.id}'>#{group.title}</option>")

      # Reset dependent fields
      resetRepairCauseSelection($content)
      resetRepairServiceSelection($content)
      hideRepairInfo($content)

      # Show extended row
      $extendedRow.fadeIn()

window.hideRepairSelection = ($extendedRow) ->
  $extendedRow.fadeOut()
  resetRepairSelection($extendedRow.find('.repair-selection'))

# Step 1: When cause GROUP selected → load causes
$(document).on 'change', '.repair-cause-group-select', ->
  $select = $(this)
  group_id = $select.val()
  $container = $select.closest('.repair-selection')
  product_id = $container.data('product-id')

  # Reset dependent fields
  resetRepairCauseSelection($container)
  resetRepairServiceSelection($container)
  hideRepairInfo($container)

  if group_id
    $.getJSON "/repair_causes/for_group/#{group_id}", {product_id: product_id}, (causes) ->
      $causeSelect = $container.find('.repair-cause-select')
      $causeSelect.html('<option value="">Выберите причину</option>')

      $.each causes, (i, cause) ->
        $causeSelect.append("<option value='#{cause.id}'>#{cause.title}</option>")

      $container.find('.repair-cause-select-group').fadeIn()

# Step 2: When CAUSE selected → load repair services
$(document).on 'change', '.repair-cause-select', ->
  $select = $(this)
  cause_id = $select.val()
  $container = $select.closest('.repair-selection')
  product_id = $container.data('product-id')
  department_id = $container.data('department-id')

  # Reset dependent fields
  resetRepairServiceSelection($container)
  hideRepairInfo($container)

  if cause_id
    $.getJSON "/repair_causes/#{cause_id}/repair_services", {product_id: product_id, department_id: department_id}, (services) ->
      $serviceSelect = $container.find('.repair-service-select')
      $serviceSelect.html('<option value="">Выберите вид ремонта</option>')

      $.each services, (i, service) ->
        $serviceSelect.append("<option value='#{service.id}' data-price='#{service.price}' data-time='#{service.time_standard}' data-time-from='#{service.time_standard_from}' data-time-to='#{service.time_standard_to}'>#{service.name}</option>")

      $container.find('.repair-service-select-group').fadeIn()

# Step 3: When REPAIR SERVICE selected → show info
$(document).on 'change', '.repair-service-select', ->
  $select = $(this)
  $container = $select.closest('.repair-selection')
  $option = $select.find('option:selected')

  if $select.val()
    displayRepairInfo($container, {
      price: $option.data('price')
      time_standard: $option.data('time')
      time_standard_from: $option.data('time-from')
      time_standard_to: $option.data('time-to')
    })
  else
    hideRepairInfo($container)

# Display repair info (price and time)
displayRepairInfo = ($container, data) ->
  $info = $container.find('.repair-info')

  # Price
  if data.price
    $info.find('.repair-price').text("#{data.price} руб.")
  else
    $info.find('.repair-price').text('Не указана')

  # Time (with range support)
  if data.time_standard_from && data.time_standard_to
    time_text = "#{data.time_standard_from} - #{data.time_standard_to} мин"
  else if data.time_standard
    time_text = "#{data.time_standard} мин"
  else
    time_text = 'Не указано'
  $info.find('.repair-time').text(time_text)

  $info.fadeIn()

# Reset cause selection (step 2)
resetRepairCauseSelection = ($container) ->
  $container.find('.repair-cause-select').html('<option value="">Выберите причину</option>')
  $container.find('.repair-cause-select-group').hide()

# Reset service selection (step 3)
resetRepairServiceSelection = ($container) ->
  $container.find('.repair-service-select').html('<option value="">Выберите вид ремонта</option>')
  $container.find('.repair-service-select-group').hide()

# Hide repair info
hideRepairInfo = ($container) ->
  $container.find('.repair-info').hide()

# Full reset of repair selection
resetRepairSelection = ($container) ->
  $container.find('.repair-cause-group-select').html('<option value="">Выберите категорию</option>')
  resetRepairCauseSelection($container)
  resetRepairServiceSelection($container)
  hideRepairInfo($container)