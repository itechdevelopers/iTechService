class ChatChannel < ApplicationCable::Channel
  def self.broadcast_message(message)
    rendered_message = ApplicationController.render(
      partial: 'messages/message',
      locals: {message: message, current_user: nil}
    )
    ActionCable.server.broadcast('chat', {message: rendered_message, sender_id: message.user_id})
  end

  def subscribed
    stream_from 'chat'
  end

  def unsubscribed
    stop_all_streams
  end
end