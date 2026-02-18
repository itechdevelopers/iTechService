# frozen_string_literal: true

class CallTranscriptionsController < ApplicationController
  def index
    authorize CallTranscription
    @call_transcriptions = CallTranscription.order(call_date: :desc)
    @call_transcriptions = @call_transcriptions.where('call_date >= ?', parse_date(params[:date_from]).beginning_of_day) if params[:date_from].present?
    @call_transcriptions = @call_transcriptions.where('call_date <= ?', parse_date(params[:date_to]).end_of_day) if params[:date_to].present?
    @call_transcriptions = @call_transcriptions.search(params[:query], whole_word: params[:whole_word] == '1') if params[:query].present?
    @call_transcriptions = @call_transcriptions.page(params[:page])
  end

  def show
    @call_transcription = find_record CallTranscription
  end

  def audio
    @call_transcription = find_record CallTranscription
    recording_url = @call_transcription.recording_url

    if recording_url.blank?
      redirect_to @call_transcription, alert: t('call_transcriptions.audio.not_available')
      return
    end

    remote_path = extract_sftp_path(recording_url)
    data = download_from_sftp(remote_path)
    send_data data, type: 'audio/wav', disposition: 'inline', filename: File.basename(remote_path)
  rescue Net::SSH::ConnectionTimeout, Errno::ETIMEDOUT => e
    redirect_to @call_transcription, alert: t('call_transcriptions.audio.connection_timeout')
  rescue Net::SSH::AuthenticationFailed => e
    redirect_to @call_transcription, alert: t('call_transcriptions.audio.auth_failed')
  rescue Net::SFTP::StatusException => e
    redirect_to @call_transcription, alert: t('call_transcriptions.audio.file_not_found')
  rescue StandardError => e
    Rails.logger.error "[CallTranscriptions#audio] SFTP error: #{e.class} - #{e.message}"
    redirect_to @call_transcription, alert: t('call_transcriptions.audio.download_error')
  end

  private

  def parse_date(date_string)
    Date.strptime(date_string, '%d.%m.%Y')
  rescue ArgumentError
    nil
  end

  def extract_sftp_path(url)
    uri = URI.parse(url)
    uri.path
  rescue URI::InvalidURIError
    url.sub(%r{sftp://[^/]+}, '')
  end

  def download_from_sftp(remote_path)
    require 'net/sftp'

    data = nil
    Net::SFTP.start(
      ENV['SFTP_HOST'],
      ENV['SFTP_USER'],
      password: ENV['SFTP_PASSWORD'],
      port: ENV.fetch('SFTP_PORT', 22).to_i,
      timeout: 10,
      non_interactive: true,
      host_key: %w[ssh-rsa],
      append_all_supported_algorithms: true
    ) do |sftp|
      data = sftp.download!(remote_path)
    end
    data
  end
end
