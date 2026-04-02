# frozen_string_literal: true

class DutyScheduleColorSetting < ApplicationRecord
  KEYS = %w[first_shift not_working available quota_filled].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }
  validates :color, presence: true

  # Returns a hash { 'first_shift' => '#f2dede', ... } for quick lookup
  def self.colors_hash
    Rails.cache.fetch('duty_schedule_color_settings', expires_in: 1.hour) do
      pluck(:key, :color).to_h
    end
  end

  # Default colors used when DB records are missing
  DEFAULTS = {
    'first_shift'  => '#f2dede',
    'not_working'  => '#d9d9d9',
    'available'    => '#dff0d8',
    'quota_filled' => '#fcf8e3'
  }.freeze

  def self.color_for(key)
    colors_hash[key] || DEFAULTS[key]
  end
end
