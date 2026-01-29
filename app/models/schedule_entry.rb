# frozen_string_literal: true

class ScheduleEntry < ApplicationRecord
  audited associated_with: :schedule_group

  belongs_to :schedule_group
  belongs_to :user
  belongs_to :department, optional: true
  belongs_to :shift, optional: true
  belongs_to :occupation_type

  validates :date, presence: true
  validates :occupation_type, presence: true
  validates :department, :shift, presence: true, if: :requires_department_and_shift?
  validates :user_id, uniqueness: { scope: %i[schedule_group_id date] }

  def requires_department_and_shift?
    occupation_type&.counts_as_working?
  end

  scope :for_week, ->(start_date) { where(date: start_date..(start_date + 6.days)) }
  scope :for_group, ->(group) { where(schedule_group: group) }

  def display_text
    if occupation_type&.counts_as_working?
      return nil unless department&.schedule_config&.short_name && shift&.short_name

      "#{department.schedule_config.short_name}/#{shift.short_name}"
    else
      occupation_type&.name
    end
  end

  def background_color
    return '#FFFFFF' unless occupation_type

    if occupation_type.counts_as_working?
      # Working occupation → use department color
      department&.schedule_config&.color || '#FFFFFF'
    else
      # Non-working occupation (vacation, sick leave, etc.) → use occupation color
      occupation_type.color || '#FFFFFF'
    end
  end
end
