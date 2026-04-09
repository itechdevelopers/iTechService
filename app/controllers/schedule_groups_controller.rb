# frozen_string_literal: true

class ScheduleGroupsController < ApplicationController
  before_action :set_city, only: %i[index new create]
  before_action :set_schedule_group, only: %i[show edit update destroy history save_week send_to_telegram]

  def index
    authorize :schedule
    @schedule_groups = @city.schedule_groups.includes(:owner, :members)
    render 'shared/show_modal_form'
  end

  def new
    authorize :schedule
    @schedule_group = @city.schedule_groups.build(owner: current_user)
    @available_users = available_users_for_city(@city)
    @design_departments = departments_for_design_settings(@city)
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @schedule_group = @city.schedule_groups.build(schedule_group_params)
    @schedule_group.owner = current_user

    if @schedule_group.save
      update_memberships
      @schedule_groups = @city.schedule_groups.includes(:owner, :members)
    else
      @available_users = available_users_for_city(@city)
      @design_departments = departments_for_design_settings(@city)
    end
  end

  def show
    authorize :schedule
    @city = @schedule_group.city
    @week_start = parse_week_start(params[:week])
    @week_dates = (@week_start..(@week_start + 6.days)).to_a
    @members = @schedule_group.members
                               .where('users.is_fired IS NOT TRUE OR users.dismissed_date >= ?', @week_start)
                               .reorder('users.created_at ASC')
    @dismissed_dates = @members.where.not(dismissed_date: nil)
                               .pluck(:id, :dismissed_date)
                               .map { |id, date| [id, date.to_date] }
                               .to_h
    @entries = @schedule_group.schedule_entries
                              .for_week(@week_start)
                              .includes(:department, :shift, :occupation_type)
                              .index_by { |e| [e.user_id, e.date] }

    # Selection panel data — only departments with configured schedule_config
    @departments = Department.in_city(@city).with_schedule_config.includes(:schedule_config).order(:name)
    @shifts = Shift.all
    @occupation_types = OccupationType.all
    @can_edit = can_edit_week?(@week_start)

    # Snapshot data for save button state
    @snapshot = @schedule_group.snapshot_for_week(@week_start)
    @has_unsaved_changes = @schedule_group.has_unsaved_changes_for_week?(@week_start)

    # Calculate weekly days off for each member
    @weekly_days_off = @members.each_with_object({}) do |member, hash|
      count = @week_dates.count do |date|
        entry = @entries[[member.id, date]]
        entry && entry.occupation_type&.is_day_off?
      end
      hash[member.id] = count
    end

    # Calculate weekly hours for each member
    @weekly_hours = @members.each_with_object({}) do |member, hash|
      hours = @week_dates.sum do |date|
        entry = @entries[[member.id, date]]
        entry&.effective_duration_hours || 0
      end
      hash[member.id] = hours
    end

    # Build department shift summary tables
    @department_summaries = build_department_summaries

    # Build total department counts (aggregated across all shifts per dept/date)
    @total_department_counts = build_total_department_counts

    # Build non-working counts per date
    @non_working_counts = build_non_working_counts

    # Load week memos
    @memos = @schedule_group.schedule_week_memos.for_week(@week_start)

    # Load time bank entries for this group's members
    @time_bank_entries = @schedule_group.time_bank_entries
                                        .includes(:user, :event_type, :created_by)
                                        .chronological
                                        .limit(50)
  end

  def edit
    authorize :schedule
    @city = @schedule_group.city
    @available_users = available_users_for_city(@city, @schedule_group)
    @design_departments = departments_for_design_settings(@city, @schedule_group)
    render 'shared/show_modal_form'
  end

  def update
    authorize :schedule
    @city = @schedule_group.city

    if @schedule_group.update(schedule_group_params)
      update_memberships
      @schedule_groups = @city.schedule_groups.includes(:owner, :members)
    else
      @available_users = available_users_for_city(@city, @schedule_group)
      @design_departments = departments_for_design_settings(@city, @schedule_group)
    end
  end

  def destroy
    authorize :schedule
    @city = @schedule_group.city

    @schedule_group.destroy

    @schedule_groups = @city.schedule_groups.includes(:owner, :members)
  end

  def history
    authorize :schedule
    @week_start = parse_week_start(params[:week])
    week_end = @week_start + 6.days

    # Get entry IDs for this week (including deleted ones from audits)
    entry_ids = @schedule_group.schedule_entries.for_week(@week_start).pluck(:id)

    # Get audits for entries of this group where the entry date falls within the week
    @audits = Audited::Audit
              .where(auditable_type: 'ScheduleEntry')
              .where(associated_type: 'ScheduleGroup', associated_id: @schedule_group.id)
              .where(
                "audited_changes->>'date' BETWEEN ? AND ? OR auditable_id IN (?)",
                @week_start.to_s, week_end.to_s, entry_ids
              )
              .includes(:user)
              .order(created_at: :desc)
              .limit(100)

    params[:form_name] = 'schedule_groups/history_modal_form_content'
    render 'shared/show_modal_form'
  end

  def save_week
    authorize :schedule
    @week_start = parse_week_start(params[:week])

    snapshot = @schedule_group.schedule_week_snapshots
                              .find_or_initialize_by(week_start: @week_start)
    snapshot.saved_at = Time.current

    if snapshot.save
      snapshot.reload
      city_tz = @schedule_group.city.time_zone || 'Vladivostok'
      render json: {
        success: true,
        saved_at: I18n.l(snapshot.saved_at.in_time_zone(city_tz), format: :short),
        first_save: snapshot.created_at == snapshot.updated_at
      }
    else
      render json: { success: false, errors: snapshot.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def send_to_telegram
    authorize :schedule

    chat_id = ENV['TELEGRAM_SCHEDULE_CHAT_ID']
    unless chat_id.present?
      render json: { success: false, error: I18n.t('schedule_groups.show.telegram_chat_not_configured') }, status: :unprocessable_entity
      return
    end

    image_data = params[:image_data]
    unless image_data.present?
      render json: { success: false, error: 'No image data provided' }, status: :unprocessable_entity
      return
    end

    # Strip data URL prefix if present
    image_data = image_data.sub(%r{\Adata:image/png;base64,}, '')

    week_start = parse_week_start(params[:week])
    week_end = week_start + 6.days
    snapshot = @schedule_group.snapshot_for_week(week_start)
    modified = snapshot && snapshot.created_at != snapshot.updated_at
    date_range = "#{I18n.l(week_start, format: '%d.%m')} - #{I18n.l(week_end, format: '%d.%m.%Y')}#{', Изменено' if modified}"
    caption = "#{@schedule_group.name} (#{date_range})\n#{current_user.short_name}"

    sender = SendTelegramSchedule.call(
      chat_id: chat_id,
      image_data: image_data,
      caption: caption
    )

    if sender.success?
      render json: { success: true }
    else
      render json: { success: false, error: sender.result }, status: :unprocessable_entity
    end
  end

  private

  def set_city
    @city = City.find(params[:city_id])
  end

  def set_schedule_group
    @schedule_group = ScheduleGroup.find(params[:id])
  end

  def schedule_group_params
    permitted = params.require(:schedule_group).permit(:name, :design_settings_json)
    if permitted[:design_settings_json].present?
      permitted[:design_settings] = JSON.parse(permitted.delete(:design_settings_json))
    else
      permitted.delete(:design_settings_json)
    end
    permitted
  rescue JSON::ParserError
    permitted.delete(:design_settings_json)
    permitted
  end

  def can_edit_week?(week_start)
    # Superadmin can edit any week (including past)
    return true if current_user.superadmin?

    # Users with manage_schedules ability can edit current and future weeks
    return false unless able_to?(:manage_schedules)

    current_week = Date.current.beginning_of_week(:monday)
    week_start >= current_week
  end

  def update_memberships
    return unless params[:member_ids]

    member_ids = params[:member_ids].reject(&:blank?).map(&:to_i)

    # Remove members not in the new list
    @schedule_group.memberships.where.not(user_id: member_ids).destroy_all

    # Add new members
    existing_member_ids = @schedule_group.memberships.pluck(:user_id)
    new_member_ids = member_ids - existing_member_ids

    new_member_ids.each do |user_id|
      @schedule_group.memberships.create(user_id: user_id)
    end
  end

  def departments_for_design_settings(city, group = nil)
    depts = Department.in_city(city).with_schedule_config.includes(:schedule_config).order(:name)
    return depts unless group&.persisted?

    # For existing groups, show only departments that are actually used in entries
    used_dept_ids = group.schedule_entries.where.not(department_id: nil).distinct.pluck(:department_id)
    depts.where(id: used_dept_ids)
  end

  def parse_week_start(week_param)
    if week_param.present?
      Date.parse(week_param).beginning_of_week(:monday)
    else
      Date.current.beginning_of_week(:monday)
    end
  rescue ArgumentError
    Date.current.beginning_of_week(:monday)
  end

  def available_users_for_city(city, current_group = nil)
    users = User.in_city(city).active.ordered

    # Exclude users already in other groups
    users_in_other_groups = ScheduleGroupMembership
                            .joins(:schedule_group)
                            .where(schedule_groups: { city_id: city.id })

    if current_group&.persisted?
      users_in_other_groups = users_in_other_groups.where.not(schedule_group_id: current_group.id)
    end

    excluded_user_ids = users_in_other_groups.pluck(:user_id)
    users.where.not(id: excluded_user_ids)
  end

  def build_non_working_counts
    # Count entries with non-working occupation type per date
    non_working = @entries.values.select { |e| e.occupation_type&.is_day_off? }

    result = {}
    non_working.each do |entry|
      result[entry.date] ||= { count: 0, users: [] }
      result[entry.date][:count] += 1
      result[entry.date][:users] << entry.user.short_name
    end
    result
  end

  def build_total_department_counts
    # Aggregate working people count per [department_id, date] across all shifts
    all_member_names = @members.map(&:short_name)
    working_entries = @entries.values.select { |e| e.occupation_type&.counts_as_working? && e.department_id }

    result = {}
    working_entries.each do |entry|
      key = [entry.department_id, entry.date]
      result[key] ||= { count: 0, users: [] }
      result[key][:count] += 1
      result[key][:users] << entry.user.short_name
    end

    result.each { |_key, data| data[:not_assigned] = all_member_names - data[:users] }
    result
  end

  def build_department_summaries
    # Collect working entries grouped by department
    working_entries = @entries.values.select { |e| e.occupation_type&.counts_as_working? && e.department_id && e.shift_id }

    # Group by department_id
    by_department = working_entries.group_by(&:department_id)

    @departments.each_with_object({}) do |dept, result|
      dept_entries = by_department[dept.id] || []
      next if dept_entries.empty?

      # Find unique shifts used in this department, ordered by shift position
      shift_ids = dept_entries.map(&:shift_id).uniq
      shifts = @shifts.select { |s| shift_ids.include?(s.id) }

      # Build columns: display_text is "DEPT_SHORT/SHIFT_SHORT"
      columns = shifts.map do |shift|
        {
          shift_id: shift.id,
          display_text: "#{dept.schedule_config.short_name}/#{shift.short_name}"
        }
      end

      # Collect all member names for "not assigned" calculation
      all_member_names = @members.map(&:short_name)

      # Count people and collect names per [shift_id, date]
      counts = {}
      dept_entries.each do |entry|
        key = [entry.shift_id, entry.date]
        counts[key] ||= { count: 0, users: [] }
        counts[key][:count] += 1
        counts[key][:users] << entry.user.short_name
      end

      # Add not_assigned to each count
      counts.each do |key, data|
        data[:not_assigned] = all_member_names - data[:users]
      end

      result[dept.id] = {
        department: dept,
        columns: columns,
        counts: counts
      }
    end
  end
end
