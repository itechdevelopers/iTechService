$(document).on 'click', '.close_product_form', ->
  $('#product_form.remote').html('')
  $('#product_form.remote').slideUp()

$(document).on 'click', '.product_selector .product_select_button', ->
  $(this).addClass('active')
  $(this).closest('.product_selector').addClass('active')

search_timeout = null
$(document).on 'keyup', '#product_choose_form #product_search_field', ->
  q = $(this).val()
  clearTimeout(search_timeout) if search_timeout?
  search_timeout = setTimeout (->
    $.get '/products.js', q: q, choose: true, form: $('#modal_form #form').val()
  ), 500

$(document).on 'keyup', '#product_choose_form #item_search_field', ->
  q = $(this).val()
  return if q.length < 2
  clearTimeout(search_timeout) if search_timeout?
  search_timeout = setTimeout (->
    $.get '/items.js',
      q: q,
      product_id: $('#selected_product').val(),
      choose: true,
      form: $('#modal_form #form').val(),
      association: $('#modal_form #association').val()
  ), 500

$(document).on 'click', '#product_choose_form #clear_product_search_field', ->
  $('#product_choose_form #product_search_field').val('')
  $.get '/products.js', choose: true

$(document).on 'click', '#product_choose_form #clear_item_search_field', ->
  $('#product_choose_form #item_search_field').val('')

$(document).on 'click', '#product_choose_form .product_row', ->
  $form = $('#product_choose_form')
  $('#product_id', $form).removeAttr('disabled').val($(this).data('product'))
  $('#item_id', $form).attr('disabled', true)
  $form.submit()

$(document).on 'click', '#product_choose_form .item_row', ->
  $form = $('#product_choose_form')
  $('#item_id', $form).removeAttr('disabled').val($(this).data('item'))
  $form.submit()

$(document).on 'click', '#product_choose_form #add_product_item', ->
  $('#product_choose_form #selected_item').attr('disabled', true).val('')
  $('#product_choose_form #new_item_fields input').removeAttr('disabled')
  $('#product_choose_form #new_item_fields').show()
  $(this).hide()

$(document).on 'keydown', '#product_choose_form #new_item_fields input, #product_choose_form #product_search_field, #product_choose_form #item_search_field', ->
  if event.keyCode is 13
    event.preventDefault()

$(document).on 'change', '#product_form .product_option', ->
  text = $('#product_group_name, .product_option>option:selected').map(->
    $(this).text().trim()).get().join(' ')
  $('#product_name').val(text)

validation_timeout = null
$(document).on 'keyup', '#product_choose_form #new_item_fields input', ->
  clearTimeout(validation_timeout) if validation_timeout?
  validation_timeout = setTimeout (->
    is_valid = true
    $('#product_choose_form #new_item_fields input').each (i, input)->
      is_valid = false if input.value.trim() is ''
    if is_valid
      $('#product_choose_form #submit_product_button').removeAttr('disabled')
    else
      $('#product_choose_form #submit_product_button').attr('disabled', true)
  ), 500

$(document).on 'click', '.add_fields', ->
  $('.product_select_button:last').click()


$ ->
  initMultiselect = ->
    $('.multiselect-rep-services-table').multiselect
      includeSelectAllOption: true
      enableFiltering: true
      enableCaseInsensitiveFiltering: true
      buttonWidth: '100%'
      maxHeight: 300
      selectAllText: 'Выбрать все'
      nonSelectedText: 'Виды ремонта'
      nSelectedText: 'выбрано'
      allSelectedText: 'Все выбраны'
      onInitialized: ->
        $('.multiselect-rep-services-table .multiselect-group, .multiselect-rep-services-table .multiselect-option, .multiselect-rep-services-table .multiselect-all').each ->
          $(this).attr('type', 'button')
          return
        return

  handleCheckboxes = ->
    $('.select-all-checkbox').on 'change', ->
      $('.product-checkbox').prop('checked', $(this).prop('checked'))
      updateSubmitButton()

    $('.product-checkbox').on 'change', ->
      if !$(this).prop('checked')
        $('.select-all-checkbox').prop('checked', false)
      else if $('.product-checkbox:checked').length == $('.product-checkbox').length
        $('.select-all-checkbox').prop('checked', true)
      updateSubmitButton()

    $('.multiselect-rep-services-table').on 'change', ->
      updateSubmitButton()

  updateSubmitButton = ->
    if $('.product-checkbox:checked').length > 0 && $('.multiselect-rep-services').val()?.length > 0
      $('#batch_update_submit').prop('disabled', false)
    else
      $('#batch_update_submit').prop('disabled', true)

  initMultiselect()
  handleCheckboxes()

  if $('.multiselect-rep-causes').length
    $('.multiselect-rep-causes').multiselect
      enableClickableOptGroups: true,
      nonSelectedText: 'Все причины',
      includeSelectAllOption: true,
      selectAllText: 'Все причины',
      onInitialized: ->
        $('.multiselect-rep-causes .multiselect-group, .multiselect-rep-causes .multiselect-option, .multiselect-rep-causes .multiselect-all').each ->
          $(this).attr('type', 'button')
          return
        return
      onChange: (element, checked) ->
        brands = $('.multiselect-rep-causes option:selected')
        selected = []
        $(brands).each (index, brand) ->
          selected.push [ $(this).val() ]
          return
        return

  if $('.multiselect-rep-services').length
    $('.multiselect-rep-services').multiselect
      enableClickableOptGroups: false,
      nonSelectedText: 'Все виды ремонта',
      selectAllText: 'Все виды ремонта',
      onInitialized: ->
        $('.multiselect-rep-services .multiselect-group, .multiselect-rep-services .multiselect-option, .multiselect-rep-services .multiselect-all').each ->
          $(this).attr('type', 'button')
          return
        return
      onChange: (element, checked) ->
        brands = $('.multiselect-rep-services option:selected')
        selected = []
        $(brands).each (index, brand) ->
          selected.push [ $(this).val() ]
          return
        return

$(document).on 'ajax:success', '.pagination a', ->
  setTimeout ->
    handleCheckboxes()
  , 100
