class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[destroy, close]

  def destroy
    authorize @notification
    @notification.destroy

    respond_to do |format|
      format.js
    end
  end

  def user_notifications
    authorize Notification
    @notifications = current_user.notifications.not_closed.page(params[:page])

    respond_to do |format|
      format.js
    end
  end

  def close
    authorize @notification
    @notification.close

    respond_to do |format|
      format.js
    end
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end