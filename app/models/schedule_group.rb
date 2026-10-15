# frozen_string_literal: true

class ScheduleGroup < ApplicationRecord
  DEFAULT_DESIGN_SETTINGS = {
    'date_cell_bg_color' => '#f9f9f9',
    'date_cell_font_color' => '#333333',
    'member_cell_bg_color' => '#ffffff',
    'member_cell_font_color' => '#333333',
    'table_font_bold' => false,
    'table_border_width' => 1,
    'table_border_color' => '#dddddd',
    'department_colors' => {}
  }.freeze

  belongs_to :city
  belongs_to :owner, class_name: 'User', foreign_key: 'user_id'

  has_many :memberships, class_name: 'ScheduleGroupMembership', dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :active_memberships, -> { where(active: true) }, class_name: 'ScheduleGroupMembership'
  has_many :active_members, through: :active_memberships, source: :user
  has_many :schedule_entries, dependent: :destroy
  has_many :schedule_week_snapshots, dependent: :destroy
  has_many :schedule_week_memos, dependent: :destroy
  has_many :time_bank_entries, dependent: :destroy

  validates :name, presence: true

  def owned_by?(user)
    user_id == user.id
  end

  # Returns design settings merged with defaults, so new keys always have values
  def effective_design_settings
    DEFAULT_DESIGN_SETTINGS.merge(design_settings || {})
  end

  # Shortcut to get a specific design setting
  def design_setting(key)
    effective_design_settings[key.to_s]
  end

  # Returns department color override for this group, or nil if not overridden
  def department_color_override(department_id)
    (design_settings || {}).dig('department_colors', department_id.to_s)
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

  # The week table hides members fired before that week, so user_ids may be a
  # subset. Hidden members keep their slots and only the slots of the listed
  # ones are permuted — otherwise reordering one week would shift fired
  # members around in the earlier weeks where they are still shown.
  def reorder_members(user_ids)
    ordered = memberships.to_a
    queue = user_ids.map(&:to_i) & ordered.map(&:user_id)
    by_user = ordered.index_by(&:user_id)
    slots = ordered.each_index.select { |i| queue.include?(ordered[i].user_id) }
    slots.zip(queue).each { |slot, user_id| ordered[slot] = by_user[user_id] }

    transaction do
      ordered.each_with_index do |membership, position|
        membership.update_column(:position, position) unless membership.position == position
      end
    end
  end
end
