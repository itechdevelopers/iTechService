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
      @weekly_hours = calculate_weekly_hours_for_users([@entry.user_id])
      @department_counts = calculate_department_counts_for_week
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
    @weekly_hours = calculate_weekly_hours_for_users([@user_id])
    @department_counts = calculate_department_counts_for_week
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
    @weekly_hours = calculate_weekly_hours_for_users(user_ids)
    @department_counts = calculate_department_counts_for_week
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

    @weekly_hours = calculate_weekly_hours_for_users(user_ids)
    @department_counts = calculate_department_counts_for_week
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

    # Get all working entries for the week
    entries = @schedule_group.schedule_entries
                             .where(date: week_dates_range)
                             .includes(:occupation_type)
                             .select { |e| e.occupation_type&.counts_as_working? && e.department_id && e.shift_id }

    # Count by [department_id, shift_id, date]
    counts = entries.each_with_object({}) do |entry, hash|
      key = [entry.department_id, entry.shift_id, entry.date.to_s]
      hash[key] = (hash[key] || 0) + 1
    end

    # Combine dept+shift pairs from BEFORE the change (captured in before_action)
    # with current pairs to ensure we update cells that became empty
    current_pairs = entries.map { |e| [e.department_id, e.shift_id] }.uniq
    all_pairs = ((@existing_dept_shift_pairs || []) + current_pairs).uniq

    result = {}
    all_pairs.each do |dept_id, shift_id|
      week_dates_range.each do |date|
        key = [dept_id, shift_id, date.to_s]
        result[key] = counts[key] || 0
      end
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
end
