# frozen_string_literal: true

require 'open-uri'
require 'tempfile'

# Downloads a photo an employee sent to the bot and attaches it to a service
# job's photo division (reception / in_operation / completed). Runs off the
# webhook cycle: fetching the file from Telegram and uploading it to cloud
# storage (CarrierWave/Fog) is too slow to do inline in the webhook response.
# Enqueued per photo by TelegramWebhookController#handle_photo.
#
#   TelegramPhotoAttachJob.perform_later(service_job.id, 'reception', file_id, author.id)
class TelegramPhotoAttachJob < ApplicationJob
  queue_as :default

  # Connect/read to api.telegram.org can time out intermittently (notably from
  # RU networks). These are transient: raise them so retry_on re-runs the job
  # with backoff instead of losing the photo. Non-transient failures (no
  # file_path, HTTP 401/404, bad file) are NOT here — those give up at once.
  TRANSIENT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout,
                      Errno::ETIMEDOUT, Errno::ECONNRESET, SocketError,
                      HTTPClient::ConnectTimeoutError].freeze
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  # retry_on takes a single exception class, so register one per transient type.
  # After the attempts are exhausted the block runs and tells the employee.
  TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 4 do |job, error|
      job.send(:notify_download_giveup, error)
    end
  end

  def perform(service_job_id, division, file_id, author_id)
    service_job = ServiceJob.find_by(id: service_job_id)
    author = User.find_by(id: author_id)
    return unless service_job && author
    return unless PhotoContainer::PHOTO_DIVISIONS.include?(division)

    tempfile = download_photo(file_id)
    unless tempfile
      return notify(author, 'Не удалось скачать фото из Telegram. Попробуйте отправить ещё раз.')
    end

    container = photo_container_for(service_job)

    result = container.with_lock do
      container.reload
      container.add_photos(
        division,
        [tempfile],
        author_name: author.short_name
      )
    end

    if result[:added].zero?
      notify(author, "❌ В этом разделе уже #{PhotoContainer::PHOTOS_PER_DIVISION_LIMIT} фото — " \
                     "больше добавить нельзя. Фото по работе №#{service_job.ticket_number} не сохранено.")
    else
      notify(author, "✅ Фото сохранено в раздел «#{division_label(division)}» " \
                     "работы №#{service_job.ticket_number}.")
    end
  ensure
    tempfile&.close!
  end

  private

  def division_label(division)
    {
      'reception' => 'Фото при приёмке',
      'in_operation' => 'Фото в процессе ремонта',
      'completed' => 'Фото готового устройства'
    }.fetch(division, division)
  end

  # Finds or creates the job's photo container, mirroring
  # ServiceJobs::PhotosController#set_photo_container.
  def photo_container_for(service_job)
    return service_job.photo_container if service_job.photo_container

    container = PhotoContainer.create!
    service_job.update_column(:photo_container_id, container.id)
    container
  end

  # Telegram file download is two steps: getFile -> file_path, then fetch from
  # the /file/bot<token>/<path> endpoint. Returns a rewound Tempfile, or nil on
  # a non-transient failure. Transient network errors are re-raised so the job
  # retries (see TRANSIENT_ERRORS / retry_on).
  def download_photo(file_id)
    response = Telegram.bot.get_file(file_id: file_id)
    path = response.dig('result', 'file_path')
    unless path
      Rails.logger.warn("[TelegramPhotoAttachJob] getFile returned no file_path: #{response.inspect}")
      return
    end

    url = "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{path}"
    fetch_to_tempfile(url, File.extname(path).presence || '.jpg')
  end

  def fetch_to_tempfile(url, ext)
    tempfile = Tempfile.new(['tg_photo', ext])
    tempfile.binmode
    URI.open(url, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |remote|
      IO.copy_stream(remote, tempfile)
    end
    tempfile.rewind
    tempfile
  rescue *TRANSIENT_ERRORS
    tempfile&.close!
    raise # let retry_on re-run the download with backoff
  rescue StandardError => e
    Rails.logger.error("[TelegramPhotoAttachJob] download failed: #{e.class}: #{e.message}")
    tempfile&.close!
    nil
  end

  def notify_download_giveup(error)
    Rails.logger.error("[TelegramPhotoAttachJob] giving up after retries: #{error.class}: #{error.message}")
    author = User.find_by(id: arguments.last)
    return unless author

    notify(author, 'Не удалось скачать фото из Telegram из-за проблем со связью. ' \
                   'Попробуйте отправить его ещё раз.')
  end

  def notify(author, text)
    NotifyEmployee.call(user: author, text: CGI.escapeHTML(text))
  rescue StandardError => e
    Rails.logger.error(
      "[TelegramPhotoAttachJob] notification failed: #{e.class}: #{e.message}"
    )
  end
end
