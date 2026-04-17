# frozen_string_literal: true

class ScheduleEntry < ApplicationRecord
  audited associated_with: :schedule_group

  belongs_to :schedule_group
  belongs_to :user
  belongs_to :department, optional: true
  belongs_to :shift, optional: true
  belongs_to :occupation_type

  before_validation :clear_work_fields_for_non_working_occupation

  validates :date, presence: true
  validates :occupation_type, presence: true
  validates :department, :shift, presence: true, if: :requires_department_and_shift?
  validates :department, presence: true, if: :requires_department_for_custom_shift?
  validates :user_id, uniqueness: { scope: %i[schedule_group_id date] }
  validate :custom_shift_times_consistency

  def requires_department_and_shift?
    occupation_type&.counts_as_working? && !custom_shift?
  end

  def requires_department_for_custom_shift?
    occupation_type&.counts_as_working? && custom_shift?
  end

  def custom_shift?
    custom_start_time.present? && custom_end_time.present?
  end

  def effective_duration_hours
    if custom_shift?
      # Use seconds_since_midnight to avoid PostgreSQL time column timezone
      # date-wrapping bug (e.g. 09:45+10 stored as 23:45 UTC → reads back as Jan 2)
      diff = custom_end_time.seconds_since_midnight - custom_start_time.seconds_since_midnight
      (diff / 3600.0).round(1)
    else
      shift&.duration_hours || 0
    end
  end

  scope :for_week, ->(start_date) { where(date: start_date..(start_date + 6.days)) }
  scope :for_group, ->(group) { where(schedule_group: group) }

  def display_text
    if occupation_type&.counts_as_working?
      if custom_shift?
        start_str = custom_start_time.strftime('%H:%M')
        end_str = custom_end_time.strftime('%H:%M')
        dept_short = department&.schedule_config&.short_name
        if dept_short
          header = occupation_type.is_other_work? ? "#{dept_short}/#{occupation_type.name}" : dept_short
          "#{header}\n#{start_str}-#{end_str}"
        else
          "#{start_str}-#{end_str}"
        end
      else
        return nil unless department&.schedule_config&.short_name && shift&.short_name

        base = "#{department.schedule_config.short_name}/#{shift.short_name}"
        occupation_type.is_other_work? ? "#{base}/#{occupation_type.name}" : base
      end
    else
      occupation_type&.name
    end
  end

  def use_department_color?
    occupation_type&.counts_as_working? && !occupation_type&.is_other_work?
  end

  def background_color
    return '#FFFFFF' unless occupation_type

    if occupation_type.counts_as_working? && !occupation_type.is_other_work?
      # Regular working occupation → use department color
      department&.schedule_config&.color || '#FFFFFF'
    else
      # Non-working OR other-work occupation → use occupation color
      occupation_type.color || '#FFFFFF'
    end
  end

  private

  def clear_work_fields_for_non_working_occupation
    return if occupation_type.nil? || occupation_type.counts_as_working?

    self.department_id = nil
    self.shift_id = nil
    self.custom_start_time = nil
    self.custom_end_time = nil
  end

  def custom_shift_times_consistency
    if custom_start_time.present? != custom_end_time.present?
      errors.add(:base, 'Укажите оба времени для кастомной смены')
    end
    if custom_shift? && custom_end_time.seconds_since_midnight <= custom_start_time.seconds_since_midnight
      errors.add(:custom_end_time, 'должно быть позже начала')
    end
    if custom_shift? && shift_id.present?
      errors.add(:base, 'Нельзя указать и смену, и кастомное время одновременно')
    end
  end
end
