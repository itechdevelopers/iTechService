jQuery ->

  window.setInterval ->
    console.log($('#purchase_form_autosave'))
    $('#purchase_form_autosave').submit()
  , 50000

  $(document).on 'blur', '.batch_fields>.price>input, .batch_fields>.quantity>input', ->
    $row = $(this).closest('.batch_fields')
    price = Number($('.price>input', $row).val())
    quantity = Number($('.quantity>input', $row).val())
    $('.sum>input', $row).val(price * quantity)

    total_sum = 0
    $('#batches .batch_fields').each ->
      sum = Number($(this).find('.sum>input').val())
      total_sum = total_sum + sum

    $('#batches .total_sum').text(total_sum)

  $(document).on 'click', '#purchase_form .add_fields, #purchase_form .remove_fields', ->
    enumerate_table('#batches')

  if $('#batches').length > 0
    enumerate_table('#batches')

#  $(document).on 'click', '.product_selector .product_link', ->
#    slideSpeed = 100
#    $link = $(this)
#    $li = $link.parent()
#    $list = $link.next('ul')
#
#    if $li.hasClass('opened')
#      $list.find('ul li').slideUp(slideSpeed).removeClass('opened').addClass('closed')
#      $list.find('ul').addClass('hidden')
#      $list.children('li').slideDown(slideSpeed).removeClass('opened').addClass('closed')
#    else
#      $list = $link.next('ul')
#      $li.prevAll('li').slideUp(slideSpeed)
#      $li.nextAll('li').slideUp(slideSpeed)
#      $list.removeClass('hidden')
#      $list.children('li').slideDown(slideSpeed).removeClass('opened').addClass('closed')
#      $li.removeClass('closed').addClass('opened')
#
#    if $list.hasClass('empty')
#      $selector = $li.closest('.product_selector')
#      $row = $li.closest('tr.batch_fields')
#      $('.product_name', $selector).text($li.attr('product_name'))
#      $('input.product_id', $selector).val($li.attr('product_id'))
#      $('.product_select_button', $selector).parent().removeClass('open')
#
#      feature_types = eval($li.attr('feature_types'))
#      if feature_types.length > 0
#        fields_id = $('input.product_id', $row).attr('id').replace('product_id', 'features')
#        fields_name = $('input.product_id', $row).attr('name').replace('product_id', 'features')
#        for feature_type in feature_types
#          field_id = "#{fields_id}_#{feature_type[0]}_id"
#          field_name = "#{fields_name}[#{feature_type[0]}][id]"
#          field_value = feature_type[0]
#          $('.features', $row).append("<input class='string required input-medium' id='#{field_id}' name='#{field_name}' type='hidden' value='#{field_value}'>")
#          field_id = "#{fields_id}_#{feature_type[0]}_value"
#          field_name = "#{fields_name}[#{feature_type[0]}][value]"
#          $('.features', $row).append("<input class='string required input-medium' id='#{field_id}' name='#{field_name}' type='text' placeholder='#{feature_type[1]}'>")
#      else
#        $('.features', $row).html('')
#
#    false

#  $(document).on 'click', '.product_selector .clear_product', ->
#    $selector = $(this).closest('.product_selector')
#    $list = $('.products_list', $selector)
#    $('li', $list).removeClass('opened').addClass('closed').hide()
#    $('li>ul', $list).addClass('hidden')
#    $list.children('li').show()
#    $('.product_name', $selector).text('-')
#    $('.product_selector', $selector).next('.product_id').val('')

update_acts_building_buttons = ->
  product_ids = $('#batches :checkbox:checked').map(->
    return $(this).attr('product_id')
  ).get().join(',')
  url = $('#new_revaluation_act_button').attr('action').split('?')[0]
  $('#new_revaluation_act_button').attr('action', "#{url}?product_ids=#{product_ids}")

  item_ids = $('#batches :checkbox:checked').map(->
    return $(this).attr('item_id')
  ).get().join(',')
  url = $('#new_movement_act_button').attr('action').split('?')[0]
  $('#new_movement_act_button').attr('action', "#{url}?item_ids=#{item_ids}")

$(document).on 'change', '#product_category_id', ->
  id = $(this).val()
  $('#feature_types').load '/products/category_select?category_id=' + id, ->
    if $('#feature_types').length > 0
      $('#feature_types').removeClass('hidden')
    else
      $('#feature_types').addClass('hidden')

$(document).on 'change', '#batches .batch_fields :checkbox', ->
  update_acts_building_buttons()

$(document).on 'click', '.purchase #new_revaluation_act_link', ->
  ids = $('#batches :checkbox:checked').map(->
    return $(this).attr('product_id')
  ).get().join(',')
  url = $('#new_revaluation_act_link').attr('href').split('?')[0]
  $('#new_revaluation_act_link').attr('href', "#{url}?product_ids=#{ids}")

$(document).on 'click', '.purchase #new_movement_act_link', ->
  ids = $('#batches :checkbox:checked').map(->
    return $(this).attr('item_id')
  ).get().join(',')
  url = $('#new_movement_act_link').attr('href').split('?')[0]
  $('#new_movement_act_link').attr('href', "#{url}?item_ids=#{ids}")

$(document).on 'change', '#purchase_select_all_batches', ->
  is_checked = this.checked
  $('#batches .batch_fields :checkbox').each ->
    this.checked = is_checked
    true
  update_acts_building_buttons()