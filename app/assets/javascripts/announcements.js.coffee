jQuery ->

  if $('#birthday_announcements').length
    $.getScript('/announcements/birthdays')


$(document).on 'click', '.change_announce_state_button', ->
  $this = $(this)
  state = !$this.data('state')
  $.ajax
    type: 'PUT'
    dataType: 'json'
    url: 'announcements/' + $this.data('id') + '.json'
    data:
      announcement:
        active: state
    success: (data)->
      $this.data('state', data.active)
      if data.active
        $this.removeClass('icon-check-empty').addClass('icon-check')
      else
        $this.removeClass('icon-check').addClass('icon-check-empty')
    error: (jqXHR, textStatus, errorThrown)->
      alert jqXHR.status+' ('+errorThrown+')'