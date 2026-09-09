# frozen_string_literal: true

require 'open-uri'
require 'tempfile'
require 'excon' # fog-aws uploads through excon; we retry on its network errors

# Downloads a clip an employee sent to the bot and stores it as a
# ServiceJobVideo. Enqueued per video by TelegramWebhookController#handle_video.
#
#   TelegramVideoAttachJob.perform_later(job.id, 'reception', author.id, video)
#
# `video` is the Telegram video object exactly as it arrived, string-keyed:
# file_id, file_unique_id, duration, file_size and an optional thumb. Passing
# it whole keeps the webhook side free of unpacking and lets the job apply its
# own limits without a second look at the update.
#
# The employee already got a "получено, сохраняю" ack from the webhook, so this
# job owns the definitive answer: every path out of #perform must end in either
# a ✅ or a ❌ message, exactly as in TelegramPhotoAttachJob.
class TelegramVideoAttachJob < ApplicationJob
  # Not :default, where photos go. Sidekiq runs two workers with strict queue
  # priority (config/sidekiq.yml), and one clip holds a worker for tens of
  # seconds — two of them on :default would stall SMS and other notifications
  # for that whole time. On :low a clip can never preempt anything that
  # matters; the cost is that it waits out a busy :default, which the employee
  # does not feel because the ack has already gone out.
  queue_as :low

  # Same two hops as the photo job: api.telegram.org (open-uri) and the storage
  # host (excon under fog-aws).
  TRANSIENT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout,
                      Errno::ETIMEDOUT, Errno::ECONNRESET, SocketError,
                      HTTPClient::TimeoutError,
                      Excon::Error::Timeout, Excon::Error::Socket].freeze
  OPEN_TIMEOUT = 10
  # Photos make do with 30s. A 20 MB clip leaving a workshop over mobile uplink
  # does not, and a premature timeout turns a healthy video into a retry cycle
  # ending in a ❌ the employee cannot act on.
  READ_TIMEOUT = 180

  # Declared BEFORE the retry_on calls: Rails picks a handler by walking the
  # list backwards, so a catch-all declared after them would swallow the
  # transient errors and silently disable every retry.
  #
  # It does not re-raise — the employee is a more reliable retry channel than
  # Sidekiq's own 25-attempt policy, which could surface the clip days later.
  rescue_from(StandardError) do |error|
    Rails.logger.error(
      "[TelegramVideoAttachJob] unhandled failure: #{error.class}: #{error.message}"
    )
    notify_author('❌ Не удалось сохранить видео в Айс. Отправьте его ещё раз.')
  end

  TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 4 do |job, error|
      job.send(:notify_giveup, error)
    end
  end

  def perform(service_job_id, division, author_id, video)
    service_job = ServiceJob.find_by(id: service_job_id)
    author = User.find_by(id: author_id)
    return unless service_job && author
    return unless ServiceJobVideo::DIVISIONS.include?(division)

    file_unique_id = video['file_unique_id']
    return notify(author, already_saved_text(service_job, division)) if
      already_attached?(service_job_id, division, file_unique_id)

    if ServiceJobVideo.division_full?(service_job_id, division)
      return notify(author, "❌ В разделе «#{ServiceJobVideo.division_label(division)}» " \
                            "уже #{ServiceJobVideo::PER_DIVISION_LIMIT} видео — больше добавить " \
                            "нельзя. Видео по работе №#{service_job.ticket_number} не сохранено.")
    end

    tempfile = download(video['file_id'], '.mp4')
    unless tempfile
      return notify(author, '❌ Не удалось скачать видео из Telegram. Отправьте его ещё раз.')
    end

    poster = download_poster(video.dig('thumb', 'file_id'))

    ServiceJobVideo.create!(
      service_job: service_job,
      division: division,
      author: author,
      duration: video['duration'],
      size: video['file_size'],
      telegram_file_unique_id: file_unique_id,
      file: tempfile,
      poster: poster
    )

    notify(author, "✅ Видео сохранено в раздел «#{ServiceJobVideo.division_label(division)}» " \
                   "работы №#{service_job.ticket_number}.")
  rescue ActiveRecord::RecordNotUnique
    # The unique index caught a re-delivered update that slipped past the
    # check above — two workers can be holding the same clip at once.
    notify(author, already_saved_text(service_job, division))
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[TelegramVideoAttachJob] rejected by uploader: #{e.message}")
    notify(author, '❌ Этот файл не похож на видео и не сохранён. ' \
                   'Снимите ролик камерой и отправьте его обычным сообщением.')
  ensure
    tempfile&.close!
    poster&.close!
  end

  private

  def already_saved_text(service_job, division)
    "✅ Это видео уже сохранено в раздел «#{ServiceJobVideo.division_label(division)}» " \
      "работы №#{service_job.ticket_number}."
  end

  # Deduplication lives in the table itself (unique index on service_job_id +
  # division + telegram_file_unique_id) rather than in Redis the way the photo
  # job does it: the marker and the record can no longer disagree, and a Redis
  # flush cannot resurrect a duplicate.
  def already_attached?(service_job_id, division, file_unique_id)
    return false if file_unique_id.blank?

    ServiceJobVideo.exists?(service_job_id: service_job_id, division: division,
                            telegram_file_unique_id: file_unique_id)
  end

  def download(file_id, default_ext)
    response = Telegram.bot.get_file(file_id: file_id)
    path = response.dig('result', 'file_path')
    unless path
      Rails.logger.warn("[TelegramVideoAttachJob] getFile returned no file_path: #{response.inspect}")
      return
    end

    fetch_to_tempfile("https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{path}",
                      File.extname(path).presence || default_ext)
  end

  # The cover frame is cosmetic: a clip without one still plays, so no failure
  # here may cost the employee their video.
  def download_poster(thumb_file_id)
    return if thumb_file_id.blank?

    download(thumb_file_id, '.jpg')
  rescue StandardError => e
    Rails.logger.warn("[TelegramVideoAttachJob] poster download failed: #{e.class}: #{e.message}")
    nil
  end

  def fetch_to_tempfile(url, ext)
    tempfile = Tempfile.new(['tg_video', ext])
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
    Rails.logger.error("[TelegramVideoAttachJob] download failed: #{e.class}: #{e.message}")
    tempfile&.close!
    nil
  end

  # `error` is the exception CLASS on Rails 5.1, not the raised object — see
  # ApplicationJob#error_label.
  def notify_giveup(error)
    Rails.logger.error("[TelegramVideoAttachJob] giving up after retries: #{error_label(error)}")
    notify_author('❌ Не удалось сохранить видео в Айс из-за проблем со связью. ' \
                  'Отправьте его ещё раз.')
  end

  # Used by the failure handlers, which run outside #perform and only have the
  # job arguments to work with. author_id is the 3rd one.
  def notify_author(text)
    author = User.find_by(id: arguments[2])
    return unless author

    notify(author, text)
  end

  def notify(author, text)
    NotifyEmployeeJob.perform_later(author.id, CGI.escapeHTML(text))
  rescue StandardError => e
    Rails.logger.error(
      "[TelegramVideoAttachJob] notification failed: #{e.class}: #{e.message}"
    )
  end
end
