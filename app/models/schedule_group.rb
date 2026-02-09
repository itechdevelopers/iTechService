# frozen_string_literal: true

class ScheduleGroup < ApplicationRecord
  belongs_to :city
  belongs_to :owner, class_name: 'User', foreign_key: 'user_id'

  has_many :memberships, class_name: 'ScheduleGroupMembership', dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :schedule_entries, dependent: :destroy
  has_many :schedule_week_snapshots, dependent: :destroy
  has_many :schedule_week_memos, dependent: :destroy

  validates :name, presence: true

  def owned_by?(user)
    user_id == user.id
  end

  # Find snapshot for a specific week
  def snapshot_for_week(week_start)
    schedule_week_snapshots.find_by(week_start: week_start)
  end

  # Check if there are unsaved changes for a specific week
  # Returns true if:
  # - No snapshot exists for this week (never saved)
  # - Snapshot exists but entries were updated after saved_at
  def has_unsaved_changes_for_week?(week_start)
    snapshot = snapshot_for_week(week_start)
    return true unless snapshot

    snapshot.has_unsaved_changes?
  end

  # Get the latest entry update time for a specific week
  def latest_entry_update_for_week(week_start)
    schedule_entries.for_week(week_start).maximum(:updated_at)
  end
end
