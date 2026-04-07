class CreateEmploymentPeriods < ActiveRecord::Migration[5.1]
  def up
    create_table :employment_periods do |t|
      t.references :user, null: false, foreign_key: true
      t.date :started_at, null: false
      t.date :ended_at
      t.references :dismissal_reason, foreign_key: true
      t.text :dismissal_comment
      t.text :rehire_reason
      t.timestamps
    end

    add_index :employment_periods, [:user_id, :started_at], unique: true

    # Backfill from existing user data
    execute <<-SQL.squish
      INSERT INTO employment_periods (user_id, started_at, ended_at, dismissal_reason_id, dismissal_comment, created_at, updated_at)
      SELECT
        id,
        hiring_date,
        CASE
          WHEN is_fired = TRUE AND dismissed_date IS NOT NULL THEN dismissed_date::date
          WHEN is_fired = TRUE AND dismissed_date IS NULL THEN updated_at::date
          ELSE NULL
        END,
        CASE WHEN is_fired = TRUE THEN dismissal_reason_id ELSE NULL END,
        CASE WHEN is_fired = TRUE THEN dismissal_comment ELSE NULL END,
        NOW(),
        NOW()
      FROM users
      WHERE hiring_date IS NOT NULL
    SQL
  end

  def down
    drop_table :employment_periods
  end
end
