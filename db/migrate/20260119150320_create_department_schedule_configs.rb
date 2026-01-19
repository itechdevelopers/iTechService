class CreateDepartmentScheduleConfigs < ActiveRecord::Migration[5.1]
  def change
    create_table :department_schedule_configs do |t|
      t.references :department, foreign_key: true, null: false, index: { unique: true }
      t.string :short_name, limit: 10
      t.string :color, limit: 7, default: '#CCCCCC'

      t.timestamps
    end
  end
end
