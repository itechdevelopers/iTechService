# frozen_string_literal: true

class CreateScheduleGroups < ActiveRecord::Migration[5.1]
  def change
    create_table :schedule_groups do |t|
      t.string :name, null: false
      t.references :city, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false

      t.timestamps
    end
  end
end
