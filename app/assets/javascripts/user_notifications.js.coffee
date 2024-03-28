jQuery ->
  if $('#user_notifications').length
    $.getScript('/notifications/user_notifications')

$(document).on 'click', "#user_notifications", (event) ->
  event.preventDefault()