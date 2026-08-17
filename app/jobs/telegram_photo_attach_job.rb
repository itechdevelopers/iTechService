# frozen_string_literal: true

require 'open-uri'
require 'tempfile'
require 'excon' # fog-aws uploads through excon; we retry on its network errors

# Downloads a photo an employee sent to the bot and attaches it to a service
# job's photo division (reception / in_operation / completed). Runs off the
# webhook cycle: fetching the file from Telegram and uploading it to cloud
# storage (CarrierWave/Fog) is too slow to do inline in the webhook response.
# Enqueued per photo by TelegramWebhookController#handle_photo.
#
#   TelegramPhotoAttachJob.perform_later(service_job.id, 'reception', file_id,
#                                        author.id, file_unique_id)
#
# The employee already got a "получено, сохраняю" ack from the webhook, so this
# job owns the definitive answer: every path out of #perform must end in either
# a ✅ or a ❌ message. A silent death here reads to the employee as "бот принял
# фото, а в Айсе пусто" — the exact failure this job is written to avoid.
class TelegramPhotoAttachJob < ApplicationJob
  queue_as :default

  # Network hiccups worth retrying, across both hops the job makes:
  # api.telegram.org (HTTPClient inside the gem, open-uri for the file itself)
  # and the storage host (excon under fog-aws). HTTPClient::TimeoutError is the
  # parent of the Connect/Send/Receive variants. Non-transient failures (no
  # file_path, HTTP 401/404, bad file) are NOT here — those give up at once.
  TRANSIENT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout,
                      Errno::ETIMEDOUT, Errno::ECONNRESET, SocketError,
                      HTTPClient::TimeoutError,
                      Excon::Error::Timeout, Excon::Error::Socket].freeze
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30
  # How long a delivered photo blocks a repeat of the same file_unique_id.
  # Telegram stops re-sending an undelivered update after ~24h.
  DEDUP_TTL = 3.days.to_i

  # Declared BEFORE the retry_on calls on purpose. Rails picks the handler by
  # walking the list backwards, so the later-declared retry_on entries claim
  # their own classes first and only what none of them matched lands here.
  # Declaring this catch-all after them would swallow the transient errors too
  # and silently disable every retry.
  #
  # This handler does not re-raise: the employee is the more reliable retry
  # channel than Sidekiq is. Re-raising would hand the job to Sidekiq's own
  # policy (25 attempts over ~3 weeks) and the photo could surface days later.
  rescue_from(StandardError) do |error|
    Rails.logger.error(
      "[TelegramPhotoAttachJob] unhandled failure: #{error.class}: #{error.message}"
    )
    notify_author('❌ Не удалось сохранить фото в Айс. Отправьте его ещё раз.')
  end

  # retry_on takes a single exception class, so register one per transient type.
  # After the attempts are exhausted the block runs and tells the employee.
  TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 4 do |job, error|
      job.send(:notify_giveup, error)
    end
  end

  def perform(service_job_id, division, file_id, author_id, file_unique_id = nil)
    service_job = ServiceJob.find_by(id: service_job_id)
    author = User.find_by(id: author_id)
    return unless service_job && author
    return unless PhotoContainer::PHOTO_DIVISIONS.include?(division)

    dedup_key = dedup_key_for(service_job_id, division, file_unique_id)
    if already_attached?(dedup_key)
      return notify(author, "✅ Это фото уже сохранено в раздел «#{division_label(division)}» " \
                            "работы №#{service_job.ticket_number}.")
    end

    tempfile = download_photo(file_id)
    unless tempfile
      return notify(author, '❌ Не удалось скачать фото из Telegram. Отправьте его ещё раз.')
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
      mark_attached(dedup_key)
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
      'completed' => 'Фото готового устройства',
      'breakage' => 'Фото поломки и работы'
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

  # Marker of an already attached photo, kept in Redis rather than in the
  # container's *_photos_meta_data: that column is a string[] of stringified
  # hashes which the gallery helper parses with regexps, so an extra key there
  # would risk breaking the whole gallery. nil when the enqueuing side did not
  # pass a file_unique_id (jobs queued before this argument existed).
  def dedup_key_for(service_job_id, division, file_unique_id)
    return if file_unique_id.blank?

    "tg_photo_attached:#{service_job_id}:#{division}:#{file_unique_id}"
  end

  # Both Redis helpers fail open: an unreachable Redis must not cost the
  # employee their photo, a duplicate is the cheaper error here.
  def already_attached?(key)
    return false if key.blank?

    Sidekiq.redis { |conn| conn.exists?(key) }
  rescue StandardError => e
    Rails.logger.warn("[TelegramPhotoAttachJob] dedup lookup failed: #{e.class}: #{e.message}")
    false
  end

  def mark_attached(key)
    return if key.blank?

    Sidekiq.redis { |conn| conn.set(key, '1', ex: DEDUP_TTL) }
  rescue StandardError => e
    Rails.logger.warn("[TelegramPhotoAttachJob] dedup write failed: #{e.class}: #{e.message}")
  end

  # `error` is the exception CLASS on Rails 5.1, not the raised object — see
  # ApplicationJob#error_label. Interpolating it directly would blow up here
  # and cost the employee the ❌ this handler exists to send.
  def notify_giveup(error)
    Rails.logger.error("[TelegramPhotoAttachJob] giving up after retries: #{error_label(error)}")
    notify_author('❌ Не удалось сохранить фото в Айс из-за проблем со связью. ' \
                  'Отправьте его ещё раз.')
  end

  # Used by the failure handlers, which run outside #perform and only have the
  # job arguments to work with. author_id is the 4th one — not the last, since
  # file_unique_id was appended after it.
  def notify_author(text)
    author = User.find_by(id: arguments[3])
    return unless author

    notify(author, text)
  end

  # Enqueued rather than sent inline: delivery gets its own retries there, and
  # a hung sendMessage no longer holds the worker. Still rescued — a photo that
  # is already stored must not be re-downloaded just because the ✅ failed.
  def notify(author, text)
    NotifyEmployeeJob.perform_later(author.id, CGI.escapeHTML(text))
  rescue StandardError => e
    Rails.logger.error(
      "[TelegramPhotoAttachJob] notification failed: #{e.class}: #{e.message}"
    )
  end
end
