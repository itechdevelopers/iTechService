# frozen_string_literal: true

class ScheduleWeekSnapshot < ApplicationRecord
  belongs_to :schedule_group

  validates :week_start, presence: true
  validates :saved_at, presence: true
  validates :schedule_group_id, uniqueness: { scope: :week_start }

  # Check if there are unsaved changes for this week
  # Returns true if any schedule_entry was updated after the snapshot was saved
  def has_unsaved_changes?
    latest_entry_update = schedule_group.schedule_entries
                                        .for_week(week_start)
                                        .maximum(:updated_at)
    return false unless latest_entry_update

    latest_entry_update > saved_at
  end
end
