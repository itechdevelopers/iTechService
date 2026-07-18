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
    result = container.add_photos(division, [tempfile], author_name: author.short_name)

    if result[:added].zero?
      notify(author, "В этом разделе уже #{PhotoContainer::PHOTOS_PER_DIVISION_LIMIT} фото — " \
                     "больше добавить нельзя. Фото по работе №#{service_job.ticket_number} не сохранено.")
    end
  ensure
    tempfile&.close!
  end

  private

  # Finds or creates the job's photo container, mirroring
  # ServiceJobs::PhotosController#set_photo_container.
  def photo_container_for(service_job)
    return service_job.photo_container if service_job.photo_container

    container = PhotoContainer.create!
    service_job.update!(photo_container: container)
    container
  end

  # Telegram file download is two steps: getFile -> file_path, then fetch from
  # the /file/bot<token>/<path> endpoint. Returns a rewound Tempfile or nil.
  def download_photo(file_id)
    response = Telegram.bot.get_file(file_id: file_id)
    path = response.dig('result', 'file_path')
    return unless path

    url = "https://api.telegram.org/file/bot#{ENV['TELEGRAM_BOT_TOKEN']}/#{path}"
    ext = File.extname(path).presence || '.jpg'
    tempfile = Tempfile.new(['tg_photo', ext])
    tempfile.binmode
    URI.open(url) { |remote| IO.copy_stream(remote, tempfile) }
    tempfile.rewind
    tempfile
  rescue StandardError => e
    Rails.logger.error("[TelegramPhotoAttachJob] download failed: #{e.class}: #{e.message}")
    tempfile&.close!
    nil
  end

  def notify(author, text)
    NotifyEmployee.call(user: author, text: CGI.escapeHTML(text))
  end
end
