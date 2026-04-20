# frozen_string_literal: true

class TranscriptionSilenceCheckJob < ApplicationJob
  queue_as :default

  def perform
    threshold = Setting.transcription_silence_threshold_hours
    return if threshold.zero?

    last_transcription = CallTranscription.order(created_at: :desc).first
    return if last_transcription.nil?

    silence_hours = ((Time.current - last_transcription.created_at) / 1.hour).round
    return if silence_hours < threshold

    notify_superadmins(silence_hours)
  end

  private

  def notify_superadmins(hours)
    recipients = User.active.superadmins
    return if recipients.empty?

    message = I18n.t('call_transcriptions.silence_notification.message', hours: hours)

    url = Rails.application.routes.url_helpers.call_transcriptions_path

    recipients.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(recipient, notification)
    end
  end
end
