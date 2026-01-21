# frozen_string_literal: true

class CreateScheduleGroupMemberships < ActiveRecord::Migration[5.1]
  def change
    create_table :schedule_group_memberships do |t|
      t.references :schedule_group, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :schedule_group_memberships, %i[schedule_group_id user_id], unique: true, name: 'index_schedule_group_memberships_uniqueness'
  end
end
