# frozen_string_literal: true

class ScheduleGroupsController < ApplicationController
  before_action :set_city, only: %i[index new create]
  before_action :set_schedule_group, only: %i[show edit update destroy history]

  def index
    authorize :schedule
    @schedule_groups = @city.schedule_groups.includes(:owner, :members)
    render 'shared/show_modal_form'
  end

  def new
    authorize :schedule
    @schedule_group = @city.schedule_groups.build(owner: current_user)
    @available_users = available_users_for_city(@city)
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
    end
  end

  def show
    authorize :schedule
    @city = @schedule_group.city
    @week_start = parse_week_start(params[:week])
    @week_dates = (@week_start..(@week_start + 6.days)).to_a
    @members = @schedule_group.members.ordered
    @entries = @schedule_group.schedule_entries
                              .for_week(@week_start)
                              .includes(:department, :shift, :occupation_type)
                              .index_by { |e| [e.user_id, e.date] }

    # Selection panel data
    @departments = Department.in_city(@city).active.includes(:schedule_config).order(:name)
    @shifts = Shift.all
    @occupation_types = OccupationType.all
    @can_edit = can_edit_week?(@week_start)
  end

  def edit
    authorize :schedule
    @city = @schedule_group.city
    @available_users = available_users_for_city(@city, @schedule_group)
    render 'shared/show_modal_form'
  end

  def update
    authorize :schedule
    @city = @schedule_group.city

    if can_manage_group?(@schedule_group) && @schedule_group.update(schedule_group_params)
      update_memberships
      @schedule_groups = @city.schedule_groups.includes(:owner, :members)
    else
      @available_users = available_users_for_city(@city, @schedule_group)
    end
  end

  def destroy
    authorize :schedule
    @city = @schedule_group.city

    if can_manage_group?(@schedule_group)
      @schedule_group.destroy
    end

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

  private

  def set_city
    @city = City.find(params[:city_id])
  end

  def set_schedule_group
    @schedule_group = ScheduleGroup.find(params[:id])
  end

  def schedule_group_params
    params.require(:schedule_group).permit(:name)
  end

  def can_manage_group?(group)
    current_user.superadmin? || group.owned_by?(current_user)
  end

  def can_edit_week?(week_start)
    return true if current_user.superadmin?
    return false unless @schedule_group.owned_by?(current_user)

    # Owner can edit current and future weeks
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

    new_member_ids.each_with_index do |user_id, index|
      @schedule_group.memberships.create(user_id: user_id, position: existing_member_ids.size + index)
    end
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
end
