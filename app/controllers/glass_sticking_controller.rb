class GlassStickingController < ApplicationController
  before_action :authenticate_user!

  def show
    authorize :glass_sticking
    @mode = GlassStickingRecipientsQuery::DEFAULT_MODE
    @recipients = GlassStickingRecipientsQuery.new(department: current_department, mode: @mode).call
  end

  def recipients
    authorize :glass_sticking, :recipients?
    @mode = params[:mode]
    @recipients = GlassStickingRecipientsQuery.new(
      department: current_department,
      mode: @mode,
      name: params[:name]
    ).call
    respond_to(&:js)
  end

  def notify
    authorize :glass_sticking, :notify?
    recipient = User.find(params[:recipient_id])
    status = params[:status]
    unless GlassStickingNotification.statuses.key?(status)
      head :unprocessable_entity
      return
    end

    @glass_notification = GlassStickingNotification.create!(
      sender: current_user,
      recipient: recipient,
      department: current_department,
      status: status
    )

    @recipient_name = recipient.short_name
    @status = status
    broadcast_in_app_notifications
    respond_to(&:js)
  end

  private

  def broadcast_in_app_notifications
    message = I18n.t("glass_sticking.notifications.#{@status}", full_name: @recipient_name)
    bar_user_ids = User.active
                       .where(department: current_department)
                       .where.not(id: current_user.id)
                       .joins(:location).where(locations: { code: 'bar' })
                       .pluck(:id)

    User.where(id: bar_user_ids).find_each do |user|
      next unless user.user_settings.receive_glass_sticking_notifications

      notification = Notification.create!(
        user: user,
        message: message,
        url: glass_sticking_path,
        referenceable: @glass_notification,
        kind: 'glass_sticking'
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
