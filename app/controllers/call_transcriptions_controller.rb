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
    local_path = cached_audio_path(remote_path)

    unless File.exist?(local_path)
      Rails.logger.info "[Audio] SFTP download: #{remote_path}"
      data = download_from_sftp(remote_path)
      FileUtils.mkdir_p(File.dirname(local_path))
      File.open(local_path, 'wb') { |f| f.write(data) }
      Rails.logger.info "[Audio] Cached to #{local_path} (#{data.bytesize} bytes)"
    end

    file_size = File.size(local_path)

    response.headers['Accept-Ranges'] = 'bytes'
    response.headers['Content-Type'] = 'audio/wav'

    if request.headers['Range'].present?
      ranges = request.headers['Range'].match(/bytes=(\d+)-(\d*)/)
      range_start = ranges[1].to_i
      range_end = ranges[2].present? ? ranges[2].to_i : file_size - 1
      length = range_end - range_start + 1

      response.headers['Content-Range'] = "bytes #{range_start}-#{range_end}/#{file_size}"
      response.headers['Content-Length'] = length.to_s

      send_data IO.binread(local_path, length, range_start),
                type: 'audio/wav', status: 206, disposition: 'inline'
    else
      response.headers['Content-Length'] = file_size.to_s
      send_file local_path, type: 'audio/wav', disposition: 'inline'
    end
  rescue Net::SSH::ConnectionTimeout, Errno::ETIMEDOUT
    redirect_to @call_transcription, alert: t('call_transcriptions.audio.connection_timeout')
  rescue Net::SSH::AuthenticationFailed
    redirect_to @call_transcription, alert: t('call_transcriptions.audio.auth_failed')
  rescue Net::SFTP::StatusException
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

  def cached_audio_path(remote_path)
    hash = Digest::MD5.hexdigest(remote_path)
    ext = File.extname(remote_path).presence || '.wav'
    Rails.root.join('tmp', 'audio_cache', "#{hash}#{ext}").to_s
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
