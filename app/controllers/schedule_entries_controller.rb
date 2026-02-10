# frozen_string_literal: true

class ScheduleEntriesController < ApplicationController
  before_action :set_schedule_group
  before_action :set_entry, only: :destroy
  before_action :capture_existing_dept_shift_pairs

  def upsert
    authorize :schedule
    return head(:forbidden) unless can_edit_week?

    @entry = @schedule_group.schedule_entries.find_or_initialize_by(
      user_id: params[:user_id],
      date: params[:date]
    )

    @entry.assign_attributes(entry_params)

    if @entry.save
      @entry.reload # Reload to get associations
      @weekly_days_off = calculate_weekly_days_off_for_users([@entry.user_id])
      @weekly_hours = calculate_weekly_hours_for_users([@entry.user_id])
      @department_counts = calculate_department_counts_for_week
      @total_dept_counts = calculate_total_dept_counts
      prepare_new_summary_elements
    else
      render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize :schedule
    return head(:forbidden) unless can_edit_week?

    @user_id = @entry.user_id
    @date = @entry.date
    @entry.destroy
    @weekly_days_off = calculate_weekly_days_off_for_users([@user_id])
    @weekly_hours = calculate_weekly_hours_for_users([@user_id])
    @department_counts = calculate_department_counts_for_week
    @total_dept_counts = calculate_total_dept_counts
  end

  def batch_upsert
    authorize :schedule
    return head(:forbidden) unless can_edit_week?

    @entries = []
    dates = week_dates
    user_ids = batch_user_ids

    user_ids.each do |user_id|
      dates.each do |date|
        entry = @schedule_group.schedule_entries.find_or_initialize_by(
          user_id: user_id,
          date: date
        )
        entry.assign_attributes(entry_params)
        entry.save
        @entries << entry
      end
    end

    @entries.each(&:reload)
    @weekly_days_off = calculate_weekly_days_off_for_users(user_ids)
    @weekly_hours = calculate_weekly_hours_for_users(user_ids)
    @department_counts = calculate_department_counts_for_week
    @total_dept_counts = calculate_total_dept_counts
    prepare_new_summary_elements
  end

  def batch_destroy
    authorize :schedule
    return head(:forbidden) unless can_edit_week?

    dates = week_dates
    user_ids = batch_user_ids

    @deleted_cells = []
    user_ids.each do |user_id|
      dates.each do |date|
        @deleted_cells << { user_id: user_id, date: date }
      end
    end

    @schedule_group.schedule_entries
                   .where(user_id: user_ids, date: dates)
                   .destroy_all

    @weekly_days_off = calculate_weekly_days_off_for_users(user_ids)
    @weekly_hours = calculate_weekly_hours_for_users(user_ids)
    @department_counts = calculate_department_counts_for_week
    @total_dept_counts = calculate_total_dept_counts
  end

  private

  def set_schedule_group
    @schedule_group = ScheduleGroup.find(params[:schedule_group_id])
  end

  def set_entry
    @entry = @schedule_group.schedule_entries.find(params[:id])
  end

  def entry_params
    params.permit(:department_id, :shift_id, :occupation_type_id)
  end

  def can_edit_week?
    # For destroy action, get date from @entry; for upsert/batch, from params
    date = @entry&.date || params[:date]&.to_date || week_start_from_params
    return false unless date

    week_start = date.beginning_of_week(:monday)

    # Superadmin can edit any week (including past)
    return true if current_user.superadmin?

    # Users with manage_schedules ability can edit current and future weeks
    return false unless able_to?(:manage_schedules)

    current_week = Date.current.beginning_of_week(:monday)
    week_start >= current_week
  end

  def week_start_from_params
    params[:week]&.to_date || Date.current.beginning_of_week(:monday)
  end

  def week_dates
    week_start = week_start_from_params
    # If date param present, use only that date; otherwise whole week
    if params[:date].present?
      [params[:date].to_date]
    else
      (week_start..(week_start + 6.days)).to_a
    end
  end

  def batch_user_ids
    # If user_id param present, use only that user; otherwise all members
    if params[:user_id].present?
      [params[:user_id].to_i]
    else
      @schedule_group.members.pluck(:id)
    end
  end

  def calculate_weekly_days_off_for_users(user_ids)
    week_start = week_start_from_params
    week_dates_range = (week_start..(week_start + 6.days)).to_a

    entries = @schedule_group.schedule_entries
                             .where(user_id: user_ids, date: week_dates_range)
                             .includes(:occupation_type)

    user_ids.each_with_object({}) do |user_id, hash|
      user_entries = entries.select { |e| e.user_id == user_id }
      hash[user_id] = user_entries.count { |e| !e.occupation_type&.counts_as_working? }
    end
  end

  def calculate_weekly_hours_for_users(user_ids)
    week_start = week_start_from_params
    week_dates_range = (week_start..(week_start + 6.days)).to_a

    entries = @schedule_group.schedule_entries
                             .where(user_id: user_ids, date: week_dates_range)
                             .includes(:shift)

    user_ids.each_with_object({}) do |user_id, hash|
      user_entries = entries.select { |e| e.user_id == user_id }
      hash[user_id] = user_entries.sum { |e| e.shift&.duration_hours || 0 }
    end
  end

  def calculate_department_counts_for_week
    week_start = week_start_from_params
    week_dates_range = (week_start..(week_start + 6.days)).to_a

    # Get all member names for "not assigned" calculation
    all_member_names = @schedule_group.members.map(&:short_name)

    # Get all working entries for the week
    entries = @schedule_group.schedule_entries
                             .where(date: week_dates_range)
                             .includes(:occupation_type, :user)
                             .select { |e| e.occupation_type&.counts_as_working? && e.department_id && e.shift_id }

    # Count and collect user names by [department_id, shift_id, date]
    counts = entries.each_with_object({}) do |entry, hash|
      key = [entry.department_id, entry.shift_id, entry.date.to_s]
      hash[key] ||= { count: 0, users: [] }
      hash[key][:count] += 1
      hash[key][:users] << entry.user.short_name
    end

    # Combine dept+shift pairs from BEFORE the change (captured in before_action)
    # with current pairs to ensure we update cells that became empty
    current_pairs = entries.map { |e| [e.department_id, e.shift_id] }.uniq
    all_pairs = ((@existing_dept_shift_pairs || []) + current_pairs).uniq

    result = {}
    all_pairs.each do |dept_id, shift_id|
      week_dates_range.each do |date|
        key = [dept_id, shift_id, date.to_s]
        data = counts[key] || { count: 0, users: [] }
        data[:not_assigned] = all_member_names - data[:users]
        result[key] = data
      end
    end

    result
  end

  def calculate_total_dept_counts
    week_start = week_start_from_params
    week_dates_range = (week_start..(week_start + 6.days)).to_a

    all_entries = @schedule_group.schedule_entries
                                 .where(date: week_dates_range)
                                 .includes(:occupation_type)

    working = all_entries.select { |e| e.occupation_type&.counts_as_working? && e.department_id }

    result = {}
    working.each do |entry|
      key = [entry.department_id, entry.date.to_s]
      result[key] ||= 0
      result[key] += 1
    end

    # Ensure we cover departments that became empty (from existing pairs)
    existing_dept_ids = (@existing_dept_shift_pairs || []).map(&:first).uniq
    current_dept_ids = working.map(&:department_id).uniq
    all_dept_ids = (existing_dept_ids + current_dept_ids).uniq

    all_dept_ids.each do |dept_id|
      week_dates_range.each do |date|
        key = [dept_id, date.to_s]
        result[key] ||= 0
      end
    end

    # Also compute non-working counts per date
    @non_working_counts = {}
    week_dates_range.each { |d| @non_working_counts[d.to_s] = 0 }
    all_entries.select { |e| e.occupation_type && !e.occupation_type.counts_as_working? }.each do |entry|
      @non_working_counts[entry.date.to_s] += 1
    end

    result
  end

  def capture_existing_dept_shift_pairs
    week_start = week_start_from_params
    week_dates_range = (week_start..(week_start + 6.days)).to_a

    entries = @schedule_group.schedule_entries
                             .where(date: week_dates_range)
                             .includes(:occupation_type)
                             .select { |e| e.occupation_type&.counts_as_working? && e.department_id && e.shift_id }

    @existing_dept_shift_pairs = entries.map { |e| [e.department_id, e.shift_id] }.uniq
  end

  def prepare_new_summary_elements
    week_start = week_start_from_params
    @week_dates = (week_start..(week_start + 6.days)).to_a

    # Get all member names for "not assigned" calculation
    all_member_names = @schedule_group.members.map(&:short_name)

    # Get current working entries
    entries = @schedule_group.schedule_entries
                             .where(date: @week_dates)
                             .includes(:occupation_type, :department, :shift, :user)
                             .select { |e| e.occupation_type&.counts_as_working? && e.department_id && e.shift_id }

    current_pairs = entries.map { |e| [e.department_id, e.shift_id] }.uniq
    new_pairs = current_pairs - (@existing_dept_shift_pairs || [])

    return if new_pairs.empty?

    # Group new pairs by department
    new_by_dept = new_pairs.group_by(&:first)

    # Determine which departments are completely new (no existing pairs)
    existing_dept_ids = (@existing_dept_shift_pairs || []).map(&:first).uniq
    new_dept_ids = new_by_dept.keys - existing_dept_ids

    # Load required data
    city = @schedule_group.city
    departments = Department.in_city(city).with_schedule_config.includes(:schedule_config).where(id: new_by_dept.keys)
    shifts = Shift.where(id: new_pairs.map(&:second).uniq)

    # Build counts and user names for new elements
    counts = entries.each_with_object({}) do |entry, hash|
      key = [entry.shift_id, entry.date]
      hash[key] ||= { count: 0, users: [] }
      hash[key][:count] += 1
      hash[key][:users] << entry.user.short_name
    end

    # Add not_assigned to each count
    counts.each do |_key, data|
      data[:not_assigned] = all_member_names - data[:users]
    end

    @new_tables = []
    @new_columns = []

    departments.each do |dept|
      dept_shift_ids = new_by_dept[dept.id].map(&:second)
      dept_shifts = shifts.select { |s| dept_shift_ids.include?(s.id) }

      if new_dept_ids.include?(dept.id)
        # Entire table is new
        columns = dept_shifts.map do |shift|
          { shift_id: shift.id, display_text: "#{dept.schedule_config.short_name}/#{shift.short_name}" }
        end

        @new_tables << {
          dept_id: dept.id,
          department_name: dept.name,
          columns: columns,
          counts: counts
        }
      else
        # Only new columns for existing table
        dept_shifts.each do |shift|
          @new_columns << {
            dept_id: dept.id,
            shift_id: shift.id,
            display_text: "#{dept.schedule_config.short_name}/#{shift.short_name}",
            counts: counts
          }
        end
      end
    end
  end
end
