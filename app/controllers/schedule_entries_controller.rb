# frozen_string_literal: true

class ScheduleEntriesController < ApplicationController
  before_action :set_schedule_group
  before_action :set_entry, only: :destroy

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

    return true if current_user.superadmin?
    return false unless @schedule_group.owned_by?(current_user)

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
end
