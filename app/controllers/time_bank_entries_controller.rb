# frozen_string_literal: true

class TimeBankEntriesController < ApplicationController
  before_action :set_schedule_group

  def new_entry
    authorize :schedule, :create_time_bank_entry?
    @event_types = TimeBankEventType.active.ordered
    @members = @schedule_group.active_members
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule, :create_time_bank_entry?

    user_ids = Array(params[:user_ids]).reject(&:blank?).map(&:to_i)
    days = params[:days].to_i
    minutes = compute_minutes

    if user_ids.empty?
      render js: "alert('Выберите хотя бы одного сотрудника');"
      return
    end

    if days <= 0 && minutes <= 0
      render js: "alert('Укажите количество дней или времени');"
      return
    end

    errors = []
    user_ids.each do |user_id|
      entry = @schedule_group.time_bank_entries.build(
        user_id: user_id,
        event_type_id: params[:event_type_id],
        direction: params[:direction],
        days: days,
        minutes: minutes,
        occurred_on: params[:occurred_on],
        note: params[:note].presence,
        created_by: current_user
      )
      errors << entry.errors.full_messages.join(', ') unless entry.save
    end

    if errors.any?
      render js: "alert(#{errors.join('; ').to_json});"
    else
      load_time_bank_entries
    end
  end

  def edit
    authorize :schedule, :edit_time_bank_entry?
    @entry = @schedule_group.time_bank_entries.find(params[:id])
    @event_types = TimeBankEventType.active.ordered
    params[:form_name] = 'edit_modal_form_content'
    render 'shared/show_modal_form'
  end

  def update
    authorize :schedule, :update_time_bank_entry?
    @entry = @schedule_group.time_bank_entries.find(params[:id])

    days = params[:days].to_i
    minutes = compute_minutes

    if days <= 0 && minutes <= 0
      render js: "alert('Укажите количество дней или времени');"
      return
    end

    if @entry.update(entry_params.merge(days: days, minutes: minutes))
      load_time_bank_entries
    else
      render js: "alert(#{@entry.errors.full_messages.join('; ').to_json});"
    end
  end

  def destroy
    authorize :schedule, :destroy_time_bank_entry?
    @entry = @schedule_group.time_bank_entries.find(params[:id])
    @entry.destroy
    load_time_bank_entries
  end

  private

  def set_schedule_group
    @schedule_group = ScheduleGroup.find(params[:schedule_group_id])
  end

  def compute_minutes
    hours = params[:hours].to_i
    mins = params[:mins].to_i
    hours * 60 + mins
  end

  def entry_params
    params.permit(:event_type_id, :direction, :occurred_on, :note)
  end

  def load_time_bank_entries
    @time_bank_entries = @schedule_group.time_bank_entries
                                        .includes(:user, :event_type, :created_by)
                                        .chronological
                                        .limit(50)
    @members = @schedule_group.active_members
  end
end
