# frozen_string_literal: true

class DepartmentWorkingHours < ApplicationRecord
  DAYS_OF_WEEK = {
    0 => :monday,
    1 => :tuesday,
    2 => :wednesday,
    3 => :thursday,
    4 => :friday,
    5 => :saturday,
    6 => :sunday
  }.freeze

  belongs_to :department

  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :day_of_week, uniqueness: { scope: :department_id }
  validates :opens_at, :closes_at, presence: true, unless: :is_closed?

  scope :ordered, -> { order(:day_of_week) }

  def day_name
    I18n.t("date.day_names")[day_of_week + 1] || I18n.t("date.day_names")[0]
  end

  def day_name_short
    I18n.t("date.abbr_day_names")[day_of_week + 1] || I18n.t("date.abbr_day_names")[0]
  end

  def time_range
    return nil if is_closed?
    "#{opens_at&.strftime('%H:%M')}-#{closes_at&.strftime('%H:%M')}"
  end
end
