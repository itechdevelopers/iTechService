# frozen_string_literal: true

class ScheduleGroupMembership < ApplicationRecord
  belongs_to :schedule_group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :schedule_group_id }
  validate :user_not_in_another_group_in_same_city

  default_scope { order(:position) }

  private

  def user_not_in_another_group_in_same_city
    return unless user_id && schedule_group

    existing = ScheduleGroupMembership
               .joins(:schedule_group)
               .where(user_id: user_id)
               .where(schedule_groups: { city_id: schedule_group.city_id })
               .where.not(schedule_group_id: schedule_group_id)
               .exists?

    errors.add(:user_id, :already_in_group) if existing
  end
end
