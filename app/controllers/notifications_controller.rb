class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[destroy, close]

  def index
    authorize Notification

    base_scope = current_user.notifications.not_closed
    @chip_counts = base_scope.group(:referenceable_type).count

    @filter = params[:filter].presence
    scope = base_scope
    if @filter && (@filter == 'null' || Notification::TYPE_LABELS.key?(@filter))
      scope = scope.where(referenceable_type: @filter == 'null' ? nil : @filter)
    end

    @notifications = scope.order(created_at: :desc)
                          .page(params[:page]).per(100)

    respond_to(&:js)
  end

  def destroy
    authorize @notification
    @notification.destroy

    respond_to(&:js)
  end

  def user_notifications
    authorize Notification

    scope = current_user.notifications.not_closed
    @notifications = scope.page(params[:page])
    # Флаги для цвета иконки в topbar: синий — только наклейка стекла,
    # красный — только прочие, красно-синий — и то, и другое.
    @has_glass = scope.glass_sticking.exists?
    @has_other = scope.non_glass_sticking.exists?

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