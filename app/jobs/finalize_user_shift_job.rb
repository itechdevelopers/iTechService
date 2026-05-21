class FinalizeUserShiftJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    window = user.elqueue_window
    return unless window

    # Skip and forget: if the user is actively serving a ticket at T+10,
    # we don't preempt the service nor reschedule.
    return if window.serving_client?

    ActiveRecord::Base.transaction do
      user.resume! if user.paused?
      user.update!(remember_pause: false) if user.remember_pause?
      user.free_window
    end

    ElectronicQueueChannel.broadcast_to(
      window.electronic_queue,
      action: 'window_resume',
      window_number: window.window_number
    )

    Rails.logger.info("[FinalizeUserShift] finalized user=#{user.id} window=#{window.window_number}")
  end
end
