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
    return if already_notified_today?

    notify_superadmins(silence_hours)
    mark_notified
  end

  private

  def already_notified_today?
    Setting.transcription_silence_last_notified_on == Date.current.to_s
  end

  def mark_notified
    setting = Setting.find_or_initialize_by(
      name: 'transcription_silence_last_notified_on',
      department_id: nil
    )
    setting.value = Date.current.to_s
    setting.value_type = 'string'
    setting.presentation = I18n.t('settings.transcription_silence_last_notified_on')
    setting.save!
  end

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
