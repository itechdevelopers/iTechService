$(document).on 'change', '.trade_in_evaluation_form .product_option, .trade_in_evaluation_form .product_group_select', ->
  product_group_id = $('.product_group_select').val()
  option_ids = $('#product_options select').serialize()

$(document).on 'change', '.trade_in_group_select', ->
  id = $(this).val()
  $('#product_options').html('')
  unless id is ''
    $.getScript "/product_groups/#{id}/select?scope=items&trade_in=true"