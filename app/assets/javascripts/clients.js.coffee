# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

jQuery ->

  $(document).on 'click', '#check_phone_number', (event) ->
    unless $(this).hasClass 'disabled'
      number = $('#client_full_phone_number').val()
      $.get '/clients/check_phone_number.js',
        number: number
    event.preventDefault()

  $(document).on 'keyup', '#client_full_phone_number', (event) ->
    number = $('#client_full_phone_number').val()
    checkedNumber = $('#client_phone_number_checked').data('checked_number')
    isNumberChanged = number != checkedNumber
    numberLengh = number.length
    isNumberChecked = $('#client_phone_number_checked').val() == '1'

    $('#phone_length').text(numberLengh)
    if (isNumberChecked and isNumberChanged) or !isNumberChecked
      $('#client_phone_number_checked').val('0')
      if numberLengh in [6,7,10,11]
        $('#check_phone_number').removeClass('disabled').addClass('btn-warning')
      else
        $('#check_phone_number').addClass('disabled').removeClass('btn-warning')
    $('#check_phone_number').removeClass('btn-success') if isNumberChecked and isNumberChanged

  $(document).on 'keyup', '#client_card_number', ->
    if $(this).val() isnt ''
      $('#client_questionnaire_input').removeClass 'hidden'
    else
      $('#client_questionnaire_input').addClass 'hidden'

  $(document).on 'click', '#questionnaire_link', (event)->
    $this = $ this
    params = $this.parents('form:first').serialize()
    event.currentTarget.href = '/clients/questionnaire?' + params

  $client_input = $('#client_input')
  if $client_input.length > 0

    clientSearchTimeout = null;

    $(document).on 'click', (event)->
      if $(this).parents('#clients_autocomplete_list').length is 0
        $('#clients_autocomplete_list').hide()

    $(document).on 'keyup', '#client_search', (event)->
      clearTimeout(clientSearchTimeout) if clientSearchTimeout
      $input = $('#client_search')
      if $input.val() is ''
        $('#service_job_client_id').val("");
        $('#order_customer_id').val("");
        $('#edit_client_link').attr('href', "#");
      else
        clientSearchTimeout = setTimeout (->
          $.getScript '/clients/autocomplete.js?client_q='+$input.val()
        ), 500

    if $('#clients_autocomplete_list').length
      # Не ставим инлайн-стили для v2 формы — CSS позиционирует
      unless $('.v2-form-container').length
        $('#clients_autocomplete_list').css
          left: $('#client_input').offset().left
          top: $('#client_input').offset().top + $('#client_input').outerHeight()

    $('#client_devices_resize_button').click ->
      $('.client_devices_list,#device_tasks_list').slideToggle(100)

    placeClientDevices()

placeClientDevices = ()->
  $devices = $('#client_devices')
  $input = $('#client_input')
  # Не ставим инлайн-стили для v2 формы — CSS позиционирует
  unless $('.v2-form-container').length
    $('#client_devices').css
      top: $input.offset().top - 6
      left: $input.offset().left + $input.outerWidth()
  if $('.client_devices_list', $devices).length > 0
    $devices.show()
  else
    $devices.hide()
