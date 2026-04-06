# frozen_string_literal: true

# Validates whether a user can be assigned to close the cashier for a given department+date.
# Same checks as DutyAssignmentValidator + extra check for existing duty assignment.
#
# Returns: { eligible: true/false, warnings: [...] }
class CashierAssignmentValidator
  attr_reader :user, :department, :date

  def initialize(user:, department:, date:)
    @user = user
    @department = department
    @date = date
  end

  def validate
    warnings = []

    if user.is_fired?
      warnings << I18n.t('cashier_schedules.warnings.employee_fired')
      return { eligible: false, warnings: warnings }
    end

    entry = find_schedule_entry
    unless entry
      warnings << I18n.t('cashier_schedules.warnings.no_schedule_entry')
      return { eligible: false, warnings: warnings }
    end

    unless entry.occupation_type&.counts_as_working?
      warnings << I18n.t('cashier_schedules.warnings.not_working')
      return { eligible: false, warnings: warnings }
    end

    if entry.department_id != department.id
      warnings << I18n.t('cashier_schedules.warnings.different_department',
                          department: entry.department&.name)
      return { eligible: false, warnings: warnings }
    end

    if DutyScheduleEntry.where(user_id: user.id, date: date).exists?
      warnings << I18n.t('cashier_schedules.warnings.already_on_duty')
      return { eligible: false, warnings: warnings }
    end

    validate_evening_shift(entry, warnings)
  end

  private

  def validate_evening_shift(entry, warnings)
    dept_hours = DepartmentWorkingHours.find_by(
      department: department,
      day_of_week: date.cwday - 1
    )

    if dept_hours.nil? || dept_hours.is_closed?
      warnings << I18n.t('cashier_schedules.warnings.department_closed')
      return { eligible: false, warnings: warnings }
    end

    shift_end = if entry.custom_shift?
                  entry.custom_end_time
                else
                  entry.shift&.end_time
                end

    unless shift_end
      warnings << I18n.t('cashier_schedules.warnings.no_evening_shift')
      return { eligible: false, warnings: warnings }
    end

    if shift_end.seconds_since_midnight >= dept_hours.closes_at.seconds_since_midnight
      { eligible: true, warnings: warnings }
    else
      warnings << I18n.t('cashier_schedules.warnings.shift_ends_before_closing',
                          end_time: shift_end.strftime('%H:%M'),
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
