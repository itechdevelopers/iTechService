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
    # For destroy action, get date from @entry; for upsert, from params
    date = @entry&.date || params[:date]&.to_date
    return false unless date

    week_start = date.beginning_of_week(:monday)

    return true if current_user.superadmin?
    return false unless @schedule_group.owned_by?(current_user)

    current_week = Date.current.beginning_of_week(:monday)
    week_start >= current_week
  end
end
