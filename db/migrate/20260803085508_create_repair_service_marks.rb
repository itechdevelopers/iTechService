class CreateRepairServiceMarks < ActiveRecord::Migration[5.1]
  def change
    create_table :repair_service_marks do |t|
      t.string :name, null: false
      t.string :title
      t.string :code
      t.integer :position

      t.timestamps
    end
    add_index :repair_service_marks, :code, unique: true
  end
end
