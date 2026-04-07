class RemoveUniqueIndexFromEmploymentPeriods < ActiveRecord::Migration[5.1]
  def change
    remove_index :employment_periods, [:user_id, :started_at]
    add_index :employment_periods, [:user_id, :started_at]
  end
end
