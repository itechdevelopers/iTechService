$(document).on 'change', '.employee-statistics__plan-input', ->
  $input = $(this)
  data = $input.data()
  target = parseInt($input.val(), 10)
  target = 0 if isNaN(target) or target < 0
  $input.val(target)

  $input.removeClass('employee-statistics__plan-input--saved employee-statistics__plan-input--error')
  $input.addClass('employee-statistics__plan-input--saving')

  $.ajax
    url: data.url
    method: 'PATCH'
    dataType: 'json'
    data:
      month:   data.month
      city_id: data['cityId']
      metric:  data.metric
      target:  target
  .done ->
    $input.removeClass('employee-statistics__plan-input--saving')
    $input.addClass('employee-statistics__plan-input--saved')
    setTimeout (-> $input.removeClass('employee-statistics__plan-input--saved')), 1500
  .fail ->
    $input.removeClass('employee-statistics__plan-input--saving')
    $input.addClass('employee-statistics__plan-input--error')
