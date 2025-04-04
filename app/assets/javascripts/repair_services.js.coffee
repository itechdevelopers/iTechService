$(document).on 'click', '#close_repair_service_choose_form', (event)->
  event.preventDefault()
  $('#repair_services_choose_form_container').slideUp()

$(document).on 'change', '#spare_parts .quantity>input', ->
  calculateTableTotal '#spare_parts', '.cost', '.quantity'

$ ->
  window.setAllValuesFrom = (value) ->
    $('.repair_service_prices_value_from').each (_, element) ->
      $(element).find('input[type="number"]').val(value)

  window.setAllValuesTo = (value) ->
    $('.repair_service_prices_value_to').each (_, element) ->
      $(element).find('input[type="number"]').val(value)

  $(document).on 'click', '.copy-prices-btn', (e) ->
    e.preventDefault()
    $parentContainer = $(this).parent()
    currentValueFrom = $parentContainer.find('.repair_service_prices_value_from')
      .find('input[type="number"]')
      .val()
    window.setAllValuesFrom(currentValueFrom)
    currentValueTo = $parentContainer.find('.repair_service_prices_value_to')
      .find('input[type="number"]')
      .val()
    window.setAllValuesTo(currentValueTo)

  window.displayAccuratePricesTd = (repairServiceId) ->
    $("tr[data-repair-service-id='#{repairServiceId}']").find('.price').each (_, element) ->
      $(element).find('.accurate-prices-td').css('display', 'block')
      $(element).find('.range-prices-td').css('display', 'none')

  window.displayRangePricesTd = (repairServiceId) ->
    $("tr[data-repair-service-id='#{repairServiceId}']").find('.price').each (_, element) ->
      $(element).find('.accurate-prices-td').css('display', 'none')
      $(element).find('.range-prices-td').css('display', 'block')

  window.displayAccuratePrices = ->
    $('.is-range-price').each (ind, element) ->
      $element = $(element)

      currentElementNum = $element.attr('id').replace('_is_range_price', '').split('_').pop()
      valueId = "#repair_service_prices_attributes_#{currentElementNum}_value"
      valueToId = "#repair_service_prices_attributes_#{currentElementNum}_value_to"
      $(valueId).closest('.accurate-prices').css('display', 'block')
      $(valueToId).closest('.range-prices').css('display', 'none')
      $element.val('false')

  window.displayRangePrices = ->
    $('.is-range-price').each (ind, element) ->
      $element = $(element)
      
      currentElementNum = $element.attr('id').replace('_is_range_price', '').split('_').pop()
      valueId = "#repair_service_prices_attributes_#{currentElementNum}_value"
      valueToId = "#repair_service_prices_attributes_#{currentElementNum}_value_to"

      $(valueId).closest('.accurate-prices').css('display', 'none')
      $(valueToId).closest('.range-prices').css('display', 'block')
      $element.val('true')

  if $('#repair_service_has_range_prices').is(':checked')
    displayRangePrices()
  else
    displayAccuratePrices()

  window.initializeRangePricesView = ->
    $('.has-range-prices-td').each (ind, element) ->
      repairServiceId = $(element).attr('id').replace('_has_range_prices', '').split('_').pop()
      if $(element).is(':checked')
        displayRangePricesTd(repairServiceId)
      else
        displayAccuratePricesTd(repairServiceId)
    
  $(document).on 'change', '#repair_service_has_range_prices', ->
    if $(this).is(':checked')
      displayRangePrices()
    else
      displayAccuratePrices()

  $(document).on 'change', '.has-range-prices-td', ->
    repairServiceId = $(this).attr('id').replace('_has_range_prices', '').split('_').pop()
    if $(this).is(':checked')
      displayRangePricesTd(repairServiceId)
    else
      displayAccuratePricesTd(repairServiceId)
