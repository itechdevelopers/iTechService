# frozen_string_literal: true

class Shift < ApplicationRecord
  validates :name, presence: true
  validates :short_name, length: { maximum: 10 }, allow_blank: true

  default_scope { order(:position) }

  def duration_hours
    return 0 unless start_time && end_time
    # Use seconds_since_midnight to avoid PostgreSQL time column timezone
    # date-wrapping bug (e.g. 09:45+10 stored as 23:45 UTC → reads back as Jan 2)
    diff = end_time.seconds_since_midnight - start_time.seconds_since_midnight
    diff += 86_400 if diff < 0 # overnight shift (e.g. 18:00 → 02:00)
    (diff / 3600.0).round(1)
  end
end
