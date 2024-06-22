jQuery ->

  if $('#birthday_announcements').length
    $.getScript('/announcements/birthdays')

  if $('#bad_review_announcements').length
    $.getScript('/announcements/bad_reviews')

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
        $this.removeClass('fa fa-square-o').addClass('fa fa-check-square-o')
      else
        $this.removeClass('fa fa-check-square-o').addClass('fa fa-square-o')
    error: (jqXHR, textStatus, errorThrown)->
      alert jqXHR.status+' ('+errorThrown+')'