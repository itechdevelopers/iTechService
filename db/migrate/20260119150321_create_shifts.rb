class CreateShifts < ActiveRecord::Migration[5.1]
  def change
    create_table :shifts do |t|
      t.references :city, foreign_key: true, null: false
      t.string :name, null: false
      t.string :short_name, limit: 10
      t.time :start_time
      t.time :end_time
      t.integer :position, default: 0

      t.timestamps
    end
    add_index :shifts, [:city_id, :position]
  end
end
