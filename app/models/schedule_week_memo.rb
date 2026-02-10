# frozen_string_literal: true

class ScheduleWeekMemo < ApplicationRecord
  belongs_to :schedule_group

  validates :week_start, presence: true
  validates :content, presence: true

  default_scope { order(:position) }

  scope :for_week, ->(week_start) { where(week_start: week_start) }
end
