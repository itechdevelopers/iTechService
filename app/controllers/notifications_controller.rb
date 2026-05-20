class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[destroy, close]

  def destroy
    authorize @notification
    @notification.destroy

    respond_to(&:js)
  end

  def user_notifications
    authorize Notification
    @notifications = current_user.notifications.not_closed.page(params[:page])

    respond_to(&:js)
  end

  def close
    authorize @notification
    @notification.close

    respond_to(&:js)
  end

  def close_all
    authorize Notification
    current_user.notifications.not_closed.update_all(closed_at: Time.zone.now)

    respond_to(&:js)
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end