class PhotoContainer < ApplicationRecord
  include Auditable
  has_one :service_job

  PHOTO_DIVISIONS = %w[reception in_operation completed].freeze
  PHOTOS_PER_DIVISION_LIMIT = 15

  mount_uploaders :reception_photos, ServiceJobPhotoUploader
  mount_uploaders :in_operation_photos, ServiceJobPhotoUploader
  mount_uploaders :completed_photos, ServiceJobPhotoUploader
  audited associated_with: :service_job

  # Appends files to a photo division, mirroring ServiceJobs::PhotosController:
  # each file gets a parallel {user:, date:} meta entry and the division is
  # capped at PHOTOS_PER_DIVISION_LIMIT (extra files beyond the cap are dropped).
  # Kept here (not in the controller) so the bot upload path can reuse it with
  # its own author instead of current_user. Returns {added:, rejected:}.
  def add_photos(division, files, author_name:)
    raise ArgumentError, "unknown division #{division}" unless PHOTO_DIVISIONS.include?(division)

    photos = public_send("#{division}_photos")
    meta = public_send("#{division}_photos_meta_data") || []
    free = PHOTOS_PER_DIVISION_LIMIT - photos.size
    accepted = free.positive? ? files.first(free) : []

    if accepted.any?
      public_send("#{division}_photos=", photos + accepted)
      public_send("#{division}_photos_meta_data=", meta + accepted.map { meta_entry(author_name) })
      save!
    end

    { added: accepted.size, rejected: files.size - accepted.size }
  end

  private

  def meta_entry(author_name)
    { user: author_name, date: DateTime.current.strftime('%d.%m.%Y %H:%M') }
  end
end
