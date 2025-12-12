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

# Get product_id and department_id from parent container
getRepairContainerData = ($block) ->
  $container = $block.closest('.repair-selection-container')
  {
    product_id: $container.data('product-id')
    department_id: $container.data('department-id')
    field_name: $container.data('field-name')
  }

# Load services for multiple selected causes (must be defined before initRepairCauseMultiselect)
loadServicesForSelectedCauses = ($block) ->
  $select = $block.find('.repair-cause-select')
  cause_ids = $select.val() || []
  data = getRepairContainerData($block)
  product_id = data.product_id
  department_id = data.department_id

  resetRepairServiceSelection($block)
  hideRepairInfo($block)

  if cause_ids.length > 0
    $.getJSON "/repair_causes/repair_services_for_causes",
      { cause_ids: cause_ids, product_id: product_id, department_id: department_id },
      (services) ->
        $radioList = $block.find('.repair-service-radio-list')
        $radioList.empty()

        # Get field name from data attribute
        fieldName = $block.find('.repair-service-select-group').data('field-name')

        $.each services, (i, service) ->
          # Build status indicator class
          statusClass = if service.spare_parts_status then "status-#{service.spare_parts_status}" else ''

          # Build quantity text (only shown if spare_parts_qty is present)
          qtyText = if service.spare_parts_qty? then "#{service.spare_parts_qty} шт." else ''

          # Escape special marks for HTML attribute (replace quotes)
          escapedMarks = if service.special_marks then String(service.special_marks).replace(/"/g, '&quot;') else ''

          $item = $("""
            <label class="repair-service-radio-item">
              <input type="radio"
                     name="#{fieldName}"
                     value="#{service.id}"
                     data-price="#{service.price || ''}"
                     data-time="#{service.time_standard || ''}"
                     data-time-from="#{service.time_standard_from || ''}"
                     data-time-to="#{service.time_standard_to || ''}"
                     data-special-marks="#{escapedMarks}">
              <span class="service-name">#{service.name}</span>
              <span class="spare-parts-indicator #{statusClass}"></span>
              <span class="spare-parts-qty">#{qtyText}</span>
            </label>
          """)
          $radioList.append($item)

        $block.find('.repair-service-select-group').fadeIn()

# Initialize multiselect for repair causes (Вариант A — простой стиль)
initRepairCauseMultiselect = ($container) ->
  $select = $container.find('.repair-cause-select')
  return if $select.data('multiselect-initialized')

  # Save container reference for callbacks
  container = $container

  $select.multiselect
    enableClickableOptGroups: true
    nonSelectedText: 'Выберите причины'
    nSelectedText: ' выбрано'
    allSelectedText: 'Все выбраны'
    includeSelectAllOption: true
    selectAllText: 'Выбрать все'
    maxHeight: 300
    onInitialized: ->
      $select.closest('.repair-cause-select-group').find('.multiselect-group, .multiselect-option, .multiselect-all').each ->
        $(this).attr('type', 'button')
    onChange: (option, checked) ->
      # Load services when selection changes
      loadServicesForSelectedCauses(container)
      # Update "Заявленный дефект" field with selected cause names
      updateClaimedDefectField()

  $select.data('multiselect-initialized', true)

# Show repair selection form and load cause groups
window.showRepairSelection = ($extendedRow) ->
  $container = $extendedRow.find('.repair-selection-container')

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

    # Store product_id and department_id in container for all blocks
    $container.data('product-id', product_id)
    $container.data('department-id', department_id)

    # Load repair cause groups for product (for the first block)
    $.getJSON "/repair_causes/for_product/#{product_id}", (groups) ->
      $container.find('.repair-selection-block').each ->
        $block = $(this)
        $select = $block.find('.repair-cause-group-select')
        $select.html('<option value="">Выберите категорию</option>')

        $.each groups, (i, group) ->
          $select.append("<option value='#{group.id}'>#{group.title}</option>")

        # Reset dependent fields
        resetRepairCauseSelection($block)
        resetRepairServiceSelection($block)
        hideRepairInfo($block)

      # Store groups data for cloning new blocks
      $container.data('repair-groups', groups)

      # Show extended row
      $extendedRow.fadeIn()

window.hideRepairSelection = ($extendedRow) ->
  $extendedRow.fadeOut()
  $container = $extendedRow.find('.repair-selection-container')
  $container.find('.repair-selection-block').each ->
    resetRepairBlock($(this))

# Step 1: When cause GROUP selected → load causes into multiselect
$(document).on 'change', '.repair-cause-group-select', ->
  $select = $(this)
  group_id = $select.val()
  $block = $select.closest('.repair-selection-block')
  data = getRepairContainerData($block)
  product_id = data.product_id

  # Reset dependent fields
  resetRepairCauseSelection($block)
  resetRepairServiceSelection($block)
  hideRepairInfo($block)

  if group_id
    $.getJSON "/repair_causes/for_group/#{group_id}", {product_id: product_id}, (causes) ->
      $causeSelect = $block.find('.repair-cause-select')
      $causeSelect.html('')

      $.each causes, (i, cause) ->
        $causeSelect.append("<option value='#{cause.id}'>#{cause.title}</option>")

      # Initialize or rebuild multiselect with new options
      if $causeSelect.data('multiselect-initialized')
        $causeSelect.multiselect('rebuild')
      else
        initRepairCauseMultiselect($block)

      $block.find('.repair-cause-select-group').fadeIn()

# Step 3: When REPAIR SERVICE radio button selected → show info
$(document).on 'change', '.repair-service-radio-item input[type="radio"]', ->
  $radio = $(this)
  $block = $radio.closest('.repair-selection-block')

  displayRepairInfo($block, {
    price: $radio.data('price')
    time_standard: $radio.data('time')
    time_standard_from: $radio.data('time-from')
    time_standard_to: $radio.data('time-to')
  })

  # Update "Вид работы" field (v2 only)
  updateTypeOfWorkField()
  # Update "Ориентировочная стоимость ремонта" field (v2 only)
  updateEstimatedCostField()
  # Update "Ориентировочный срок ремонта / Комментарии / Особые отметки" field (v2 only)
  updateClientCommentField()
  # Update device task cost in table (v2 only)
  updateDeviceTaskCost($block)

# Format minutes to hours and minutes
formatDuration = (minutes) ->
  return null unless minutes
  minutes = parseInt(minutes)
  return null if isNaN(minutes)

  hours = Math.floor(minutes / 60)
  mins = minutes % 60

  if hours > 0 && mins > 0
    "#{hours} ч #{mins} мин"
  else if hours > 0
    "#{hours} ч"
  else
    "#{mins} мин"

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
    time_text = "#{formatDuration(data.time_standard_from)} - #{formatDuration(data.time_standard_to)}"
  else if data.time_standard
    time_text = formatDuration(data.time_standard)
  else
    time_text = 'Не указано'
  $info.find('.repair-time').text(time_text)

  $info.fadeIn()

# Reset cause selection (step 2) - with multiselect support
resetRepairCauseSelection = ($container) ->
  $causeSelect = $container.find('.repair-cause-select')
  $causeSelect.html('')
  if $causeSelect.data('multiselect-initialized')
    $causeSelect.multiselect('rebuild')
  $container.find('.repair-cause-select-group').hide()

# Reset service selection (step 3) - now uses radio buttons
resetRepairServiceSelection = ($container) ->
  $container.find('.repair-service-radio-list').empty()
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

# ========== Type of Work Auto-fill (v2 only) ==========

# Collect all selected repair service names from all blocks (now uses radio buttons)
collectRepairServiceNames = ->
  names = []
  $('.v2-form-container .repair-selection-block').each ->
    $radio = $(this).find('.repair-service-radio-item input[type="radio"]:checked')
    if $radio.length
      name = $radio.closest('.repair-service-radio-item').find('.service-name').text().trim()
      names.push(name) if name
  names

# Auto-resize textarea to fit content
autoResizeField = ($field) ->
  return unless $field.is('textarea')
  $field.css('height', 'auto')
  $field.css('height', $field[0].scrollHeight + 'px')

# Update "Вид работы" field with collected repair service names
updateTypeOfWorkField = ->
  return unless $('.v2-form-container').length > 0

  $field = $('#service_job_type_of_work')
  return unless $field.length > 0

  names = collectRepairServiceNames()
  $field.val(names.join(', '))
  autoResizeField($field)

# Collect all selected repair cause names from all blocks
collectRepairCauseNames = ->
  names = []
  $('.v2-form-container .repair-selection-block').each ->
    $select = $(this).find('.repair-cause-select')
    $select.find('option:selected').each ->
      name = $(this).text().trim()
      names.push(name) if name
  names

# Update "Заявленный дефект" field with collected repair cause names
updateClaimedDefectField = ->
  return unless $('.v2-form-container').length > 0

  $field = $('#service_job_claimed_defect')
  return unless $field.length > 0

  names = collectRepairCauseNames()
  $field.val(names.join(', '))
  autoResizeField($field)

# ========== Estimated Cost Auto-fill (v2 only) ==========

# Parse price string - returns {min, max} or null
# Handles: "1500", "1000 - 2000", null, undefined, ""
parsePriceString = (priceStr) ->
  return null unless priceStr
  priceStr = String(priceStr).trim()
  return null if priceStr == ''

  if priceStr.indexOf(' - ') > -1
    parts = priceStr.split(' - ')
    min = parseInt(parts[0], 10)
    max = parseInt(parts[1], 10)
    return null if isNaN(min) || isNaN(max)
    { min: min, max: max }
  else
    val = parseInt(priceStr, 10)
    return null if isNaN(val)
    { min: val, max: val }

# Collect all prices from selected repair services (now uses radio buttons)
collectRepairPrices = ->
  prices = []
  $('.v2-form-container .repair-selection-block').each ->
    $radio = $(this).find('.repair-service-radio-item input[type="radio"]:checked')
    if $radio.length
      priceStr = $radio.data('price')
      parsed = parsePriceString(priceStr)
      prices.push(parsed) if parsed
  prices

# Sum prices and format result
sumAndFormatPrices = (prices) ->
  return '' if prices.length == 0

  totalMin = 0
  totalMax = 0
  for p in prices
    totalMin += p.min
    totalMax += p.max

  if totalMin == totalMax
    "#{totalMin} руб."
  else
    "от #{totalMin} до #{totalMax} руб."

# Update "Ориентировочная стоимость ремонта" field
updateEstimatedCostField = ->
  return unless $('.v2-form-container').length > 0

  $field = $('#service_job_estimated_cost_of_repair')
  return unless $field.length > 0

  prices = collectRepairPrices()
  $field.val(sumAndFormatPrices(prices))

# ========== Client Comment (Special Marks) Auto-fill (v2 only) ==========

# Collect all special marks from selected repair services
collectSpecialMarks = ->
  marks = []
  $('.v2-form-container .repair-selection-block').each ->
    $radio = $(this).find('.repair-service-radio-item input[type="radio"]:checked')
    if $radio.length
      specialMarks = $radio.data('special-marks')
      if specialMarks && String(specialMarks).trim() != ''
        marks.push(String(specialMarks).trim())
  marks

# Update "Ориентировочный срок ремонта / Комментарии / Особые отметки" field
updateClientCommentField = ->
  return unless $('.v2-form-container').length > 0

  $field = $('#service_job_client_comment')
  return unless $field.length > 0

  marks = collectSpecialMarks()
  if marks.length > 0
    $field.val(marks.join('; '))
    autoResizeField($field)

# ========== Device Task Cost Update (v2 only) ==========

# Update device task cost in the tasks table when repair service is selected
updateDeviceTaskCost = ($block) ->
  return unless $('.v2-form-container').length > 0

  # Find the parent task row (device_task)
  $extendedRow = $block.closest('.task-extended-row')
  $taskRow = $extendedRow.prev('.device_task')

  return unless $taskRow.length > 0

  # Get selected radio and its price
  $radio = $block.find('.repair-service-radio-item input[type="radio"]:checked')
  return unless $radio.length > 0

  priceStr = $radio.data('price')

  # Parse price - extract numeric value from string like "1500 руб." or "1000 - 2000"
  if priceStr
    # If it's a range, take the first number
    numericPrice = String(priceStr).replace(/[^\d\-]/g, ' ').trim().split(/\s+/)[0]
    if numericPrice
      $costField = $taskRow.find('.device_task_cost')
      $costField.val(numericPrice)

# Reset a single repair block (for cloning)
resetRepairBlock = ($block) ->
  # Reset group select
  $block.find('.repair-cause-group-select').val('')

  # Destroy multiselect if exists
  $causeSelect = $block.find('.repair-cause-select')
  if $causeSelect.data('multiselect-initialized')
    $causeSelect.multiselect('destroy')
    $causeSelect.removeData('multiselect-initialized')
  $causeSelect.html('')

  # Hide and reset dependent fields
  $block.find('.repair-cause-select-group').hide()
  $block.find('.repair-service-radio-list').empty()
  $block.find('.repair-service-select-group').hide()
  $block.find('.repair-info').hide()

# Add new repair block
$(document).on 'click', '.add-repair-block-btn', (e) ->
  e.preventDefault()
  $container = $(this).closest('.repair-selection-container')
  $blocks = $container.find('.repair-selection-blocks')
  $firstBlock = $blocks.find('.repair-selection-block').first()
  groups = $container.data('repair-groups')

  # Clone the first block
  $newBlock = $firstBlock.clone()

  # Reset the cloned block
  resetRepairBlock($newBlock)

  # Populate groups dropdown
  $groupSelect = $newBlock.find('.repair-cause-group-select')
  $groupSelect.html('<option value="">Выберите категорию</option>')
  if groups
    $.each groups, (i, group) ->
      $groupSelect.append("<option value='#{group.id}'>#{group.title}</option>")

  # Remove any cloned multiselect UI elements
  $newBlock.find('.btn-group').remove()

  # Append new block
  $blocks.append($newBlock)

# ========== Preview Work Order PDF ==========

$(document).on 'click', '.preview-work-order-btn', (e) ->
  e.preventDefault()

  $btn = $(this)
  previewUrl = $btn.data('url')
  $form = $btn.closest('form')

  # Create a temporary form for POST to new tab
  previewForm = document.createElement('form')
  previewForm.method = 'POST'
  previewForm.action = previewUrl
  previewForm.target = '_blank'

  # Copy all form fields
  formData = new FormData($form[0])
  for [key, value] from formData.entries()
    input = document.createElement('input')
    input.type = 'hidden'
    input.name = key
    input.value = value
    previewForm.appendChild(input)

  # Add CSRF token
  csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  if csrfToken
    csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    previewForm.appendChild(csrfInput)

  document.body.appendChild(previewForm)
  previewForm.submit()
  document.body.removeChild(previewForm)