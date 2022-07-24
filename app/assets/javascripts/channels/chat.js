App.cable.subscriptions.create({channel: 'ChatChannel'}, {
  received({message, sender_id}) {
    if(App.current_user_id === sender_id) { return }

    let $messages = $('#messages')

    if($messages.length > 0) {
      $messages.prepend(message)
    } else {
      if(!$('.nav_chat').parent().hasClass('active') && $('.nav_chat>i').length == 0)
        $('.nav_chat').prepend("<i class='icon-envelope'></i> ");
    }
  }
})