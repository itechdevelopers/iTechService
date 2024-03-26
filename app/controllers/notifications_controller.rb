class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[destroy]

  def destroy
    authorize @notification
    @notification.destroy

    respond_to do |format|
      format.js
    end
  end

  def user_notifications
    Rails.logger.info("User notifications: #{current_user.notifications.not_closed.count}")
    @notifications = current_user.notifications.not_closed.page(params[:page])
    authorize @notifications

    respond_to do |format|
      format.js
    end
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end