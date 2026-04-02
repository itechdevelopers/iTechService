# frozen_string_literal: true

# Builds the data needed for the new duty schedule table.
#
# Given a city, department, and week_start:
# 1. Finds ScheduleEntries for that department+week across all schedule groups in the city
# 2. Filters to users whose Location has schedule: true
# 3. Returns structured data for rendering
class DutyScheduleQuery
  attr_reader :city, :department, :week_start

  def initialize(city:, department:, week_start:)
    @city = city
    @department = department
    @week_start = week_start.beginning_of_week(:monday)
  end

  def week_dates
    @week_dates ||= (0..6).map { |i| week_start + i.days }
  end

  # Users who work at this department during the week AND whose location has schedule: true
  def employees
    @employees ||= begin
      user_ids = schedule_entries_for_week
                   .where(department: department)
                   .select(:user_id)
                   .distinct
                   .pluck(:user_id)

      User.includes(:location, :department)
          .where(id: user_ids)
          .joins(:location)
          .where(locations: { schedule: true })
          .order('locations.name ASC, users.surname ASC, users.name ASC')
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

  # Hash of [user_id, date] => DutyScheduleEntry
  def duty_entries_index
    @duty_entries_index ||= begin
      DutyScheduleEntry
        .for_department(department)
        .for_date_range(week_dates.first, week_dates.last)
        .index_by { |e| [e.user_id, e.date] }
    end
  end

  # Hash of user_id => count of duties in the month
  def monthly_duty_counts
    @monthly_duty_counts ||= begin
      # Use the month of the first day of the week
      month_date = week_start
      DutyScheduleEntry
        .for_department(department)
        .for_month(month_date)
        .where(user_id: employees.map(&:id))
        .group(:user_id)
        .count
    end
  end

  # Stats for the header: employees count, days in month, avg duties
  def month_stats
    days = Time.days_in_month(week_start.month, week_start.year)
    emp_count = employees.size
    avg = emp_count.positive? ? (days.to_f / emp_count).round(1) : 0
    { days_in_month: days, employees_count: emp_count, avg_duties: avg }
  end

  private

  def schedule_entries_for_week
    group_ids = city.schedule_groups.pluck(:id)
    ScheduleEntry.where(schedule_group_id: group_ids).for_week(week_start)
  end
end
