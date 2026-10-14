class PhotoContainer < ApplicationRecord
  include Auditable
  has_one :service_job

  PHOTO_DIVISIONS = %w[reception in_operation completed breakage].freeze
  PHOTO_COLUMNS = PHOTO_DIVISIONS.map { |division| "#{division}_photos" }.freeze
  PHOTOS_PER_DIVISION_LIMIT = 15

  mount_uploaders :reception_photos, ServiceJobPhotoUploader
  mount_uploaders :in_operation_photos, ServiceJobPhotoUploader
  mount_uploaders :completed_photos, ServiceJobPhotoUploader
  mount_uploaders :breakage_photos, ServiceJobPhotoUploader
  audited associated_with: :service_job

  # Author for the photo history record when User.current is not set
  # (the bot attaches photos from a background job).
  attr_accessor :history_author

  after_save :record_photo_history

  # Appends files to a photo division, mirroring ServiceJobs::PhotosController:
  # each file gets a parallel {user:, date:} meta entry and the division is
  # capped at PHOTOS_PER_DIVISION_LIMIT (extra files beyond the cap are dropped).
  # Kept here (not in the controller) so the bot upload path can reuse it with
  # its own author instead of current_user. Returns {added:, rejected:}.
  def add_photos(division, files, author:)
    raise ArgumentError, "unknown division #{division}" unless PHOTO_DIVISIONS.include?(division)

    photos = public_send("#{division}_photos")
    meta = public_send("#{division}_photos_meta_data") || []
    free = PHOTOS_PER_DIVISION_LIMIT - photos.size
    accepted = free.positive? ? files.first(free) : []

    if accepted.any?
      self.history_author = author
      public_send("#{division}_photos=", photos + accepted)
      public_send("#{division}_photos_meta_data=", meta + accepted.map { meta_entry(author.short_name) })
      save!
    end

    { added: accepted.size, rejected: files.size - accepted.size }
  end

  private

  # The history modal shows service_job.history_records, so photo changes are
  # recorded on the job, one row per changed division, with photo counts as
  # old/new values. The job is looked up afresh: `audited associated_with`
  # reads #service_job while the container is still unattached, caching nil
  # for the rest of the request.
  def record_photo_history
    changes = PHOTO_COLUMNS.each_with_object({}) do |column, counts|
      next unless saved_change_to_attribute?(column)

      old_count, new_count = saved_change_to_attribute(column).map { |photos| Array(photos).size }
      counts[column] = [old_count, new_count] unless old_count == new_count
    end
    return if changes.empty?

    job = ServiceJob.find_by(photo_container_id: id)
    return if job.nil?

    changes.each do |column, (old_count, new_count)|
      HistoryRecord.create!(object: job, column_name: column, column_type: 'integer',
                            old_value: old_count, new_value: new_count,
                            user: history_author || User.current)
    end
  end

  def meta_entry(author_name)
    { user: author_name, date: DateTime.current.strftime('%d.%m.%Y %H:%M') }
  end
end
