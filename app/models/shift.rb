# frozen_string_literal: true

class Shift < ApplicationRecord
  validates :name, presence: true
  validates :short_name, length: { maximum: 10 }, allow_blank: true

  default_scope { order(:position) }

  def duration_hours
    return 0 unless start_time && end_time
    ((end_time - start_time) / 3600.0).round(1)
  end
end
