# frozen_string_literal: true

# Builds the data needed for the cashier closing schedule table.
#
# Given a city, department, and week_start:
# 1. Finds ScheduleEntries for that department+week across all schedule groups in the city
# 2. Filters to users whose Location has code 'bar'
# 3. Returns structured data for rendering (including duty schedule conflicts)
class CashierScheduleQuery
  attr_reader :city, :department, :week_start

  def initialize(city:, department:, week_start:)
    @city = city
    @department = department
    @week_start = week_start.beginning_of_week(:monday)
  end

  def week_dates
    @week_dates ||= (0..6).map { |i| week_start + i.days }
  end

  # Users who work at this department during the week AND whose location is 'bar'
  def employees
    @employees ||= begin
      user_ids = schedule_entries_for_week
                   .where(department: department)
                   .select(:user_id)
                   .distinct
                   .pluck(:user_id)

      User.includes(:location, :department)
          .where(id: user_ids)
          .where('users.is_fired IS NOT TRUE OR users.dismissed_date >= ?', week_start)
          .joins(:location)
          .where(locations: { code: 'bar' })
          .order('locations.name ASC, users.surname ASC, users.name ASC')
    end
  end

  # Hash of user_id => dismissed_date for fired or scheduled-to-fire employees
  def dismissed_dates
    @dismissed_dates ||= employees.where.not(dismissed_date: nil)
                                   .pluck(:id, :dismissed_date)
                                   .map { |id, date| [id, date.to_date] }
                                   .to_h
  end

  # Hash of [user_id, date] => ScheduleEntry (all entries, not just this department)
  def schedule_entries_index
    @schedule_entries_index ||= begin
      entries = schedule_entries_for_week
                  .includes(:department, :shift, :occupation_type)
                  .where(user_id: employees.map(&:id))
      entries.index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of [user_id, date] => CashierScheduleEntry
  def cashier_entries_index
    @cashier_entries_index ||= begin
      CashierScheduleEntry
        .for_department(department)
        .for_date_range(week_dates.first, week_dates.last)
        .index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of [user_id, date] => DutyScheduleEntry (for conflict checking)
  def duty_entries_index
    @duty_entries_index ||= begin
      DutyScheduleEntry
        .for_department(department)
        .for_date_range(week_dates.first, week_dates.last)
        .where(user_id: employees.map(&:id))
        .index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of user_id => count of cashier closings in the month
  def monthly_cashier_counts
    @monthly_cashier_counts ||= begin
      month_date = week_start
      CashierScheduleEntry
        .for_department(department)
        .for_month(month_date)
        .where(user_id: employees.map(&:id))
        .group(:user_id)
        .count
    end
  end

  # Stats for the header
  def month_stats
    days = Time.days_in_month(week_start.month, week_start.year)
    emp_count = employees.size
    avg = emp_count.positive? ? (days.to_f / emp_count).round(1) : 0
    { days_in_month: days, employees_count: emp_count, avg_duties: avg }
  end

  # Hash of [user_id, date] => status_key (String or nil)
  # Possible keys: 'not_working', 'first_shift', 'available', 'quota_filled'
  # nil = no schedule entry or uncovered edge case (no color)
  def cell_statuses_index
    @cell_statuses_index ||= build_cell_statuses
  end

  private

  def build_cell_statuses
    statuses = {}
    duty_quota = month_stats[:avg_duties].to_i
    dept_hours_index = load_dept_hours_index

    employees.each do |employee|
      week_dates.each do |date|
        statuses[[employee.id, date]] = cell_status_for(
          employee, date, dept_hours_index, duty_quota
        )
      end
    end

    statuses
  end

  def cell_status_for(employee, date, dept_hours_index, duty_quota)
    entry = schedule_entries_index[[employee.id, date]]
    return nil unless entry

    # Not working or different department
    return 'not_working' unless entry.occupation_type&.counts_as_working?
    return 'not_working' if entry.department_id != department.id

    # Department closed or no shift end time
    dept_hours = dept_hours_index[date.cwday - 1]
    return nil if dept_hours.nil? || dept_hours.is_closed?

    shift_end = entry.custom_shift? ? entry.custom_end_time : entry.shift&.end_time
    return nil unless shift_end

    # First shift (shift ends before department closes)
    if shift_end.seconds_since_midnight < dept_hours.closes_at.seconds_since_midnight
      return 'first_shift'
    end

    # Already on duty — treat as not_working (can't close cashier)
    return 'not_working' if duty_entries_index[[employee.id, date]]

    # Eligible — check quota
    count = monthly_cashier_counts[employee.id] || 0
    count >= duty_quota && duty_quota.positive? ? 'quota_filled' : 'available'
  end

  def load_dept_hours_index
    DepartmentWorkingHours
      .where(department: department)
      .index_by(&:day_of_week)
  end

  def schedule_entries_for_week
    group_ids = city.schedule_groups.pluck(:id)
    ScheduleEntry.where(schedule_group_id: group_ids).for_week(week_start)
  end
end
