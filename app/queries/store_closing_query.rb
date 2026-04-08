# frozen_string_literal: true

# Builds the data needed for the store closing schedule table.
#
# Unlike DutyScheduleQuery/CashierScheduleQuery, employees come from a manual group
# (StoreClosingGroup), not from ScheduleEntry filtering by Location.
# All group members are always shown, even those without schedule entries.
class StoreClosingQuery
  attr_reader :city, :department, :group, :week_start

  def initialize(city:, department:, group:, week_start:)
    @city = city
    @department = department
    @group = group
    @week_start = week_start.beginning_of_week(:monday)
  end

  def week_dates
    @week_dates ||= (0..6).map { |i| week_start + i.days }
  end

  # All members of the group (always shown, regardless of schedule)
  def employees
    @employees ||= group.members
                        .includes(:location, :department)
                        .where('users.is_fired IS NOT TRUE OR users.dismissed_date >= ?', week_start)
                        .order('users.surname ASC, users.name ASC')
  end

  # Hash of user_id => dismissed_date for fired or scheduled-to-fire employees
  def dismissed_dates
    @dismissed_dates ||= employees.where.not(dismissed_date: nil)
                                   .pluck(:id, :dismissed_date)
                                   .map { |id, date| [id, date.to_date] }
                                   .to_h
  end

  # Members who have NO ScheduleEntry at all for this week (for warning banner)
  def members_without_schedule
    @members_without_schedule ||= begin
      ids_with_schedule = schedule_entries_for_week
                            .where(user_id: employees.map(&:id))
                            .select(:user_id)
                            .distinct
                            .pluck(:user_id)
      employees.reject { |e| ids_with_schedule.include?(e.id) }
    end
  end

  # Hash of [user_id, date] => ScheduleEntry
  def schedule_entries_index
    @schedule_entries_index ||= begin
      entries = schedule_entries_for_week
                  .includes(:department, :shift, :occupation_type)
                  .where(user_id: employees.map(&:id))
      entries.index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of [user_id, date] => StoreClosingEntry
  def store_closing_entries_index
    @store_closing_entries_index ||= begin
      StoreClosingEntry
        .for_department(department)
        .for_date_range(week_dates.first, week_dates.last)
        .where(user_id: employees.map(&:id))
        .index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of [user_id, date] => DutyScheduleEntry (for markers)
  def duty_entries_index
    @duty_entries_index ||= begin
      DutyScheduleEntry
        .for_department(department)
        .for_date_range(week_dates.first, week_dates.last)
        .where(user_id: employees.map(&:id))
        .index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of [user_id, date] => CashierScheduleEntry (for markers)
  def cashier_entries_index
    @cashier_entries_index ||= begin
      CashierScheduleEntry
        .for_department(department)
        .for_date_range(week_dates.first, week_dates.last)
        .where(user_id: employees.map(&:id))
        .index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of user_id => count of store closings in the month
  def monthly_store_closing_counts
    @monthly_store_closing_counts ||= begin
      StoreClosingEntry
        .for_department(department)
        .for_month(week_start)
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

  # Hash of [user_id, date] => status_key
  # Duty/cashier assignments do NOT affect cell status (only shown as markers)
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

    return 'not_working' unless entry.occupation_type&.counts_as_working?
    return 'not_working' if entry.department_id != department.id

    dept_hours = dept_hours_index[date.cwday - 1]
    return nil if dept_hours.nil? || dept_hours.is_closed?

    shift_end = entry.custom_shift? ? entry.custom_end_time : entry.shift&.end_time
    return nil unless shift_end

    if shift_end.seconds_since_midnight < dept_hours.closes_at.seconds_since_midnight
      return 'first_shift'
    end

    # No duty/cashier blocking here — only markers in the table

    count = monthly_store_closing_counts[employee.id] || 0
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
