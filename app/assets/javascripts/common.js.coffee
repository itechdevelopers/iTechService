jQuery ->

# Loading info and announcements

  if $('#important_info').length
    $('#important_info').load '/infos?important=t', ->
      if $('#important_info>*').length
        showNotificationsIndicator()

  if $('#personal_infos').length
    $('#personal_infos').load '/infos?personal=t', ->
      if $('#personal_infos>*').length
        showNotificationsIndicator()

  if $('#announcements').length
    $('#announcements').load '/announcements?actual=t', ->
      if $('#announcements>*').length
        showNotificationsIndicator()

  if $('#staff_experience').length
    $.getScript('/users/experience');

  $(document).ready () ->
    $('form[data-remote]').bind 'ajax:before', () ->
      CKEDITOR.instances[instance].updateElement() for instance in CKEDITOR.instances

  $('#sign_in_by_card, #unlock_session').click (event)->
    event.preventDefault()
    scanCard()

  $('#lock_session').click (event)->
    event.preventDefault()
    $('#card_sign_in').show().addClass('in')

  $('#scan_barcode_button').click ->
    scanTicket()

  $('.color_input>.color_template').css 'background-color', $('.color_value').val()

  $('.color_input>.color_value').colorpicker().on 'changeColor', (event)->
    $('.color_input>.color_template').css 'background-color', event.color.toHex()

  if $('table.enumerable').length > 0
    enumerate_table('table.enumerable')

  $('.association_filter').filterAssociation()

$(document).on 'click', '.close_popover_button', (event)->
  $popover = $(this).parents('.popover')
  $popover.prev().popover('hide')
  event.preventDefault()

$(document).on 'click', '#hide_notifications_button', ->
  $('#announcements:has(*)').slideToggle(100);
  $('#personal_infos:has(*)').slideToggle(100);
  $('#important_info:has(*)').slideToggle(100);
  $('#duty_announcement:has(*)').slideToggle(100);
  $('#hide_notifications_button>i').toggleClass('icon-chevron-up').toggleClass('icon-chevron-down')

$(document).on 'click', '#history .close_history', (event) ->
  $history = $('#history')
  $history.remove()
  event.preventDefault()

$(document).on 'click', '.remove_fields', (event) ->
  $(this).prev("input[type=hidden]").val("1")
  $(this).closest(".fields").hide()
  event.preventDefault()

$(document).on 'shown', '#modal_form', ->
  $('html,body').css('overflow', 'hidden');
  $('#modal_form textarea:first').focus();

$(document).on 'hidden', '#modal_form', ->
  $('html,body').css 'overflow', 'auto'
  $('#modal_form').hide()
  $('.product_selector.active').removeClass('active')
  $('.product_select_button.active').removeClass('active')

$(document).on 'keyup', '#search_form .search-query', (event) ->
  if event.keyCode is 13
    $('#search_form').submit()
    event.preventDefault()

$(document).on 'click', '#search_form .clear_search_input', (event) ->
  $(this).siblings('.search-query').val ''
  $('#search_form').submit()
  event.preventDefault()

$(document).on 'focus', '.datepicker', ->
  $(this).datepicker().dates = datepicker_dates

$(document).on 'click', '#cancel_barcode_scan', ->
  closeBarcodeReader()

$(document).on 'click', '.add_fields', (event) ->
  event.preventDefault()
  target = $(this).data 'selector'
  association = $(this).data 'association'
  content = $(this).data 'content'
  add_fields target, association, content

cursorX = $('#spinner').outerWidth() / 2
cursorY = $('#spinner').outerHeight() / 2

$(document).on 'click', '.close_popover_button', ->
  $owner = $($(this).data('owner'))
  $owner.popover('destroy')

$(document).on 'mousemove', '*', (event)->
  cursorX = event.pageX
  cursorY = event.pageY

$(document).on 'keydown', 'input[type=text]', ->
  cursorX = $(this).offset().left + $('#spinner').outerWidth() / 2
  cursorY = $(this).offset().top + this.clientHeight / 2

$(document).on 'keydown', 'textarea', ->
  cursorX = $(this).offset().left + $('#spinner').outerWidth() / 2
  cursorY = $(this).offset().top + $('#spinner').outerHeight() / 2

$(document).on 'keydown', '#quick_search', (e)->
  $input = $('#quick_search')
  $form = $('#service_jobs_quick_search_form')
  $result_list = $('#quick_search_result')
  switch e.which
    when 13
      if $('.active', $result_list).length
        $('.active>a', $result_list).click()
      else
        $form.submit()
      e.preventDefault()
    when 38 # up
      if $result_list.length
        if $('.active', $result_list).length
          active_item = $('#quick_search_result>.active')[0]
          prev_item = active_item.previousElementSibling
          prev_item = $('#quick_search_result>:last')[0] if prev_item is null
          $(active_item).removeClass('active')
          $(prev_item).addClass('active')
        else
          $('#quick_search_result>:last').addClass('active')
      e.preventDefault()
    when 40 # down
      if $result_list.length
        if $('.active', $result_list).length
          active_item = $('#quick_search_result>.active')[0]
          next_item = active_item.nextElementSibling
          next_item = $('#quick_search_result>:first')[0] if next_item is null
          $(active_item).removeClass('active')
          $(next_item).addClass('active')
        else
          $('#quick_search_result>:first').addClass('active')
      e.preventDefault()
    when 27 # esc
      $input.val('')
      $('#quick_search_result>.active').removeClass('active')
      $('#quick_search_result:visible').slideUp(100)
    else
      $('#quick_search_result>.active').removeClass('active')

$(document).on 'keyup', 'input.capitalize', (event)->
  input = event.target;
  start = input.selectionStart;
  end = input.selectionEnd;
  str = input.value.toLowerCase().replace /^[\u00C0-\u1FFF\u2C00-\uD7FF\w]|\s[\u00C0-\u1FFF\u2C00-\uD7FF\w]/g, (letter)->
    letter.toUpperCase();
  input.value = str
  input.setSelectionRange(start, end);

$(document).on 'keydown', 'input.upcase', (event)->
  $this = $(this)
  if (event.keyCode in [65..90]) and (event.metaKey is false) and (event.ctrlKey is false) and (event.altKey is false)
    $this.val($this.val()+String.fromCharCode(event.keyCode))
    event.preventDefault()

$(document).on 'click', '.datetime_quick_select .time_link', (event)->
  $(this).closest('.datetime_quick_select').find('input').val($(this).data('value'))
  event.preventDefault()

$(document).ajaxSend ->
  showSpinner()

$(document).ajaxComplete ->
  hideSpinner()

$(document).on 'click', '.form-inline-link', (event)->
  data_id = $(this).data('form-inline-id')
  $('.content-inline[data-form-inline-id="' + data_id + '"]').toggleClass('hidden')
  $('.form-inline[data-form-inline-id="' + data_id + '"]').toggleClass('hidden')

add_fields = (target, association, content) ->
  new_id = String((new Date).getTime()) + String(Math.floor((Math.random() * 100) + 1))
  regexp = new RegExp "new_" + association, "g"
  $(target).append content.replace(regexp, new_id)

sign_in_by_card = (number)->
  current_user_id = $('#profile_link').data('id')
  $.post '/users/sign_in_by_card.json', {card_number: number, current_user: current_user_id}, (data, status, resp)->
    new_location = resp.getResponseHeader('location')

    if window.location.pathname is "/users/sign_in"
      window.location.assign new_location
    else
      if data.id == current_user_id
        $('#card_sign_in').removeClass('in').hide()
      else
        window.location.assign new_location
      window.auth_timeout = window.auth_count = Number($('#profile_link').data('timeout-in'))

scanCard = ->
  card_number = ''
  $('#card_sign_in').show().addClass('in')
  $(document).on 'keydown', (event)->
    if $('#card_sign_in.in:visible').length > 0
      if event.keyCode is 13 and card_number isnt ''
        sign_in_by_card card_number
      else
        card_number += String.fromCharCode(event.keyCode).toLowerCase()
  setTimeout (->
    unless card_number is ''
      sign_in_by_card card_number
    else
      $('#card_sign_in').removeClass('in').hide() if window.location.pathname is "/users/sign_in"
    card_number = ''
  ), 3000

scanTicket = ->
  scaned_code = ''
  $('#barcode_reader').fadeIn().addClass('in')
  $(document).on 'keydown', (event)->
    if $('#barcode_reader:visible').length > 0
      if event.keyCode is 13 and scaned_code isnt ''
        ticket_number = scaned_code.replace(/^0+/, '')
        ticket_number = ticket_number[0..-2]
        $('#barcode_reader').removeClass('in').fadeOut()
        $.get '/service_jobs/' + ticket_number + '.js?find=ticket'
      else
        if event.keyCode in [48..57]
          scaned_code = scaned_code[1..-1] if scaned_code.length is 12
          scaned_code += String.fromCharCode(event.keyCode)

  setTimeout (->
    $('#barcode_reader').removeClass('in').fadeOut()
  ), 5000

window.auth_timeout = window.auth_count = Number($('#profile_link').data('timeout-in'))

setInterval (->
  auth_count -= 1
  if auth_count < 1 and $('#card_sign_in.in:visible').length is 0
    $('#lock_session').click()
), 1000

#$(document).on 'click keydown mousemove', ->
#  auth_count = auth_timeout

window.showScanner = (object_type)->
  scanned_number = ''
  $('#card_scanner').show().addClass('in').addClass(object_type)
  $(document).on 'keydown', (event)->
    if $('#card_scanner.in:visible').length > 0
      if event.keyCode is 13 and scanned_number isnt ''
        hideScanner()
        switch object_type
          when 'gift_certificate' then $.get('/gift_certificates/'+scanned_number+'/find.js')
          when 'attach_gift_certificate' then $.post('/sales/'+$('#sale_form').data('id')+'/attach_gift_certificate.js', {number: scanned_number})
        scanned_number = ''
      else
        scanned_number += String.fromCharCode(event.keyCode).toLowerCase()
  setTimeout (->
    scanned_number = ''
    hideScanner()
  ), 5000

window.hideScanner = ->
  $('#card_scanner_inner input').val('')
  $('#card_scanner').removeClass('in').hide()

window.closeBarcodeReader = ->
  $('#barcode_reader #barcode_field').val('')
  $('#barcode_reader').removeClass('in').fadeOut()

window.showSpinner = ()->
  $spinner = $('#spinner')
  $spinner.css
#    left: cursorX-$spinner.outerWidth()/2,
#    top: cursorY-$spinner.outerHeight()/2
  $spinner.fadeIn()

window.hideSpinner = ->
  $('#spinner').fadeOut()

window.closeAnnouncement = ($announcement)->
#  $announcement.css({position: 'fixed', left: $announcement.offset().left, top: $announcement.offset().top, width: $announcement.outerWidth()})
#  $announcement.animate({left: $('body').outerWidth()}, 200).remove()
  $announcement.slideUp 100, ->
    $announcement.remove()
    hideNotificationsIndicator() unless $('#announcements>*, #important_info>*, #personal_infos>*').length

window.showNotificationsIndicator = ->
  $('#hide_notifications_button>.indicator').addClass('active')

window.hideNotificationsIndicator = ->
  $('#hide_notifications_button>.indicator').removeClass('active')

window.hideModal = ->
  $('#modal_form').modal('hide')

window.enumerate_table = (table)->
  num = 0
  $('tbody>tr:visible', table).each ->
    $(this).find('.num').text(++num)

window.calculateTableTotal = (table, value_col, qty_col)->
  total = 0
  $('tbody>tr:visible', table).each ->
    value = accounting.unformat $(value_col, this).text()
    quantity = $(qty_col+'>input', this).val()
    total += value * quantity
  $('tfoot td.total').text accounting.formatMoney(total)

window.datepicker_dates =
  days: ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"],
  daysShort: ["Вск", "Пнд", "Втр", "Срд", "Чтв", "Птн", "Суб", "Вск"],
  daysMin: ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
  months: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"],
  monthsShort: ["Янв", "Фев", "Мар", "Апр", "Май", "Июн", "Июл", "Авг", "Сен", "Окт", "Ноя", "Дек"],
  today: "Сегодня"

window.jstree_i18n =
  create: 'Создать'
  rename: 'Переименовать'
  delete: 'Удалить'
  confirmation: 'Вы уверены?'
accounting.settings =
  currency:
    symbol: 'руб.'
    #format: '%v %s'
    format: '%v'
    decimal: ','
    thousand: ' '
    precision: 2
  number:
    precision: 2
    decimal: ','
    thousand: ' '
