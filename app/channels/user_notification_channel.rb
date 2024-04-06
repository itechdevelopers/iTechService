class UserNotificationChannel < ApplicationCable::Channel
  def self.broadcast_to(user, notification)
    rendered_n = ApplicationController.render( partial: 'notifications/short_notification', locals: { notification: notification } )
    ActionCable.server.broadcast("user_#{user.id}_notifications", rendered_n)
  end

  def subscribed
    stream_from "user_#{current_user.id}_notifications"
  end

  def unsubscribed
    stop_all_streams
  end
end