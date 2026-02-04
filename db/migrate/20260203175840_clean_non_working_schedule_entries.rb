# frozen_string_literal: true

class CleanNonWorkingScheduleEntries < ActiveRecord::Migration[5.1]
  def up
    # Clear shift_id and department_id for schedule entries
    # where occupation_type is non-working (counts_as_working = false)
    execute <<-SQL.squish
      UPDATE schedule_entries
      SET shift_id = NULL, department_id = NULL
      WHERE occupation_type_id IN (
        SELECT id FROM occupation_types WHERE counts_as_working = false
      )
      AND (shift_id IS NOT NULL OR department_id IS NOT NULL)
    SQL
  end

  def down
    # Data migration - cannot be reversed
  end
end
