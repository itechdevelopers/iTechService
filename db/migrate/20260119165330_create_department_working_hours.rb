class CreateDepartmentWorkingHours < ActiveRecord::Migration[5.1]
  def change
    create_table :department_working_hours do |t|
      t.references :department, foreign_key: true, null: false
      t.integer :day_of_week, null: false
      t.time :opens_at
      t.time :closes_at
      t.boolean :is_closed, default: false

      t.timestamps
    end
    add_index :department_working_hours, [:department_id, :day_of_week], unique: true, name: 'index_dept_working_hours_on_dept_and_day'
  end
end
