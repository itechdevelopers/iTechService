# frozen_string_literal: true

class ScheduleEntry < ApplicationRecord
  belongs_to :schedule_group
  belongs_to :user
  belongs_to :department, optional: true
  belongs_to :shift, optional: true
  belongs_to :occupation_type, optional: true

  validates :date, presence: true
  validates :user_id, uniqueness: { scope: %i[schedule_group_id date] }

  scope :for_week, ->(start_date) { where(date: start_date..(start_date + 6.days)) }
  scope :for_group, ->(group) { where(schedule_group: group) }

  def display_text
    return nil unless department&.schedule_config&.short_name && shift&.short_name

    "#{department.schedule_config.short_name}/#{shift.short_name}"
  end

  def background_color
    occupation_type&.color || '#FFFFFF'
  end
end
