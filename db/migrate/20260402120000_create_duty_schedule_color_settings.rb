# frozen_string_literal: true

class CreateDutyScheduleColorSettings < ActiveRecord::Migration[5.1]
  def up
    create_table :duty_schedule_color_settings do |t|
      t.string :key, null: false
      t.string :color, null: false
      t.timestamps
    end

    add_index :duty_schedule_color_settings, :key, unique: true

    # Seed default color settings
    now = Time.current
    execute <<-SQL.squish
      INSERT INTO duty_schedule_color_settings (key, color, created_at, updated_at) VALUES
        ('first_shift',   '#f2dede', '#{now}', '#{now}'),
        ('not_working',   '#d9d9d9', '#{now}', '#{now}'),
        ('available',     '#dff0d8', '#{now}', '#{now}'),
        ('quota_filled',  '#fcf8e3', '#{now}', '#{now}')
    SQL
  end

  def down
    drop_table :duty_schedule_color_settings
  end
end
