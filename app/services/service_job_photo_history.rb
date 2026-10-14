# Photo rows of a service job's history that predate HistoryRecord-based
# tracking (PhotoContainer#record_photo_history), rebuilt from the photo meta
# entries as unsaved HistoryRecords: one row per author and minute, with the
# number of photos added as new_value.
class ServiceJobPhotoHistory
  # Meta entries are Hash#to_s strings: {:user=>"Имя Фамилия", :date=>"18.07.2026 18:52"}
  META_ENTRY = /:user=>"(?<user>(?:[^"\\]|\\.)*)", :date=>"(?<date>[^"]*)"/.freeze
  META_DATE_FORMAT = '%d.%m.%Y %H:%M'.freeze

  def initialize(service_job)
    @job = service_job
    @container = service_job.photo_container
  end

  def legacy_records
    return [] if @container.nil?

    groups = PhotoContainer::PHOTO_COLUMNS.flat_map do |column|
      legacy_entries(column).chunk_while { |a, b| a == b }.map { |group| [column, group.first, group.size] }
    end
    authors = resolve_authors(groups.map { |(_, entry, _)| entry[:user] })
    groups.map { |column, entry, count| build_record(column, entry, count, authors[entry[:user]]) }.compact
  end

  private

  # New photos are always appended, so the legacy entries are the prefix of
  # the division's meta that existed before its first record; its length is
  # that record's old count. This holds only while meta matches the photos
  # 1:1 and nothing was removed since (a removal can hit any position);
  # otherwise the division gets no legacy rows rather than duplicates.
  # Photos are counted from the raw column, as the records count them.
  def legacy_entries(column)
    meta = Array(@container.public_send("#{column}_meta_data"))
    records = recorded[column]
    count =
      if records.blank?
        meta.size
      elsif meta.size != Array(@container.read_attribute(column)).size ||
            records.any? { |rec| rec.new_value.to_i < rec.old_value.to_i }
        0
      else
        records.first.old_value.to_i
      end
    meta.first(count).map { |raw| parse(raw) }.compact
  end

  def recorded
    @recorded ||= HistoryRecord.where(object: @job, column_name: PhotoContainer::PHOTO_COLUMNS)
                               .order(:created_at, :id).group_by(&:column_name)
  end

  def parse(raw)
    match = META_ENTRY.match(raw.to_s)
    match && { user: match[:user].gsub(/\\(.)/, '\1'), date: match[:date] }
  end

  # Meta keeps only the author's short_name; it maps to a user only when
  # exactly one has that name.
  def resolve_authors(names)
    names.uniq.each_with_object({}) do |name, authors|
      users = User.where("concat(coalesce(name, ''), ' ', coalesce(surname, '')) = :name OR username = :name", name: name)
                  .limit(2).to_a
      authors[name] = users.first if users.one?
    end
  end

  # The meta date was formatted in the uploader's time zone (requests run in
  # Time.use_zone(current_user.time_zone)); without a known author the job's
  # city is the closest guess.
  def build_record(column, entry, count, author)
    zone = Time.find_zone(author&.time_zone) || Time.find_zone(@job.department&.city&.time_zone) || Time.zone
    HistoryRecord.new(object: @job, column_name: column, column_type: 'integer', new_value: count,
                      created_at: zone.strptime(entry[:date], META_DATE_FORMAT),
                      user: author, author_name: entry[:user])
  rescue ArgumentError
    nil
  end
end
