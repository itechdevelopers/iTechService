# frozen_string_literal: true

class MarkerWordNotificationJob < ApplicationJob
  queue_as :default

  def perform(call_transcription_id)
    transcription = CallTranscription.find_by(id: call_transcription_id)
    return unless transcription

    found_markers = find_markers_in_text(transcription.transcript_text)
    return if found_markers.empty?

    notify_superadmins(transcription, found_markers)
  end

  private

  def find_markers_in_text(text)
    normalized_text = text.mb_chars.downcase.to_s
    MarkerWord.all.select { |marker| normalized_text.include?(marker.word) }
  end

  def notify_superadmins(transcription, markers)
    recipients = User.active.superadmins
    return if recipients.empty?

    words_list = markers.map(&:word).join(', ')
    message = I18n.t('marker_words.notification.message',
                     words: words_list,
                     transcription_id: transcription.id)
    url = Rails.application.routes.url_helpers.call_transcription_path(transcription)

    recipients.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        referenceable: transcription,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
