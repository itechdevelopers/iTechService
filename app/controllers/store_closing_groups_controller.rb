# frozen_string_literal: true

class StoreClosingGroupsController < ApplicationController
  def new
    authorize :schedule, :create?
    @department = Department.find(params[:department_id])
    @group = StoreClosingGroup.new(department: @department)
    @available_users = available_users
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule, :create?
    @department = Department.find(params[:store_closing_group][:department_id])

    @group = StoreClosingGroup.find_or_initialize_by(department: @department)
    @group.created_by ||= current_user

    if @group.save
      update_memberships(@group)
    else
      @available_users = available_users
    end
  end

  def edit
    authorize :schedule, :update?
    @group = StoreClosingGroup.find(params[:id])
    @department = @group.department
    @available_users = available_users
    render 'shared/show_modal_form'
  end

  def update
    authorize :schedule, :update?
    @group = StoreClosingGroup.find(params[:id])
    @department = @group.department

    update_memberships(@group)
  end

  private

  def update_memberships(group)
    return unless params[:member_ids]

    member_ids = params[:member_ids].reject(&:blank?).map(&:to_i)

    # Remove members not in the new list
    group.store_closing_memberships.where.not(user_id: member_ids).destroy_all

    # Add new members
    existing_member_ids = group.store_closing_memberships.pluck(:user_id)
    new_member_ids = member_ids - existing_member_ids

    new_member_ids.each_with_index do |user_id, index|
      group.store_closing_memberships.create!(user_id: user_id, position: existing_member_ids.size + index)
    end
  end

  def available_users
    User.active.ordered
  end
end
