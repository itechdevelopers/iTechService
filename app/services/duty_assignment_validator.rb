# frozen_string_literal: true

# Validates whether a user can be assigned as duty for a given department+date.
# Checks ScheduleEntry data to ensure the user works in the evening.
#
# Returns: { eligible: true/false, warnings: [...] }
class DutyAssignmentValidator
  attr_reader :user, :department, :date

  def initialize(user:, department:, date:)
    @user = user
    @department = department
    @date = date
  end

  def validate
    warnings = []

    entry = find_schedule_entry
    unless entry
      warnings << I18n.t('duty_schedules.warnings.no_schedule_entry')
      return { eligible: false, warnings: warnings }
    end

    unless entry.occupation_type&.counts_as_working?
      warnings << I18n.t('duty_schedules.warnings.not_working')
      return { eligible: false, warnings: warnings }
    end

    if entry.department_id != department.id
      warnings << I18n.t('duty_schedules.warnings.different_department',
                          department: entry.department&.name)
      return { eligible: false, warnings: warnings }
    end

    if entry.custom_shift?
      return validate_custom_shift(entry, warnings)
    end

    unless entry.shift&.includes_evening?
      warnings << I18n.t('duty_schedules.warnings.no_evening_shift')
      return { eligible: false, warnings: warnings }
    end

    { eligible: true, warnings: warnings }
  end

  private

  def validate_custom_shift(entry, warnings)
    dept_hours = DepartmentWorkingHours.find_by(
      department: department,
      day_of_week: date.cwday - 1
    )

    if dept_hours.nil? || dept_hours.is_closed?
      warnings << I18n.t('duty_schedules.warnings.department_closed')
      return { eligible: false, warnings: warnings }
    end

    if entry.custom_end_time.seconds_since_midnight >= dept_hours.closes_at.seconds_since_midnight
      { eligible: true, warnings: warnings }
    else
      warnings << I18n.t('duty_schedules.warnings.custom_shift_not_evening',
                          end_time: entry.custom_end_time.strftime('%H:%M'),
                          closes_at: dept_hours.closes_at.strftime('%H:%M'))
      { eligible: false, warnings: warnings }
    end
  end

  def find_schedule_entry
    city = department.city
    group_ids = city.schedule_groups.pluck(:id)
    ScheduleEntry.where(schedule_group_id: group_ids, user_id: user.id, date: date).first
  end
end
