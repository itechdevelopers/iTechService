jQuery ->

$(document).on 'click', '#calculate_payments', (event)->
  event.preventDefault()
  calculateSalePayments()

$(document).on 'change', '#payments_table .payment_kind', ->
  $this = $(this)
  $row = $this.closest('.payment_fields')
  $('.addl_attr>*', $row).addClass('hidden')
  switch $this.val()
    when 'card', 'credit' then $('.bank_field', $row).removeClass('hidden')
    when 'certificate' then $('.gift_certificate_field', $row).removeClass('hidden')
    when 'trade_in' then $('.trade_in_field', $row).removeClass('hidden')

$(document).on 'change, blur', '#payments_table .payment_value', ->
  calculateSalePayments()

calculateSalePayments = ->
  total_sum = 0
  if $('#payments_table').length > 0
    $('#payments_table .payment_value:visible').each ->
      total_sum += Number $(this).val()
  $('#payments_table #sale_payments_sum').text(accounting.formatMoney(total_sum))
  calculation_amount = Number $('#sale_calculation_amount').data('amount')
  if total_sum == calculation_amount then $('#payment_submit_button').removeAttr('disabled') else $('#payment_submit_button').attr('disabled', true)