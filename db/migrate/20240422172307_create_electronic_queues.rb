class CreateElectronicQueues < ActiveRecord::Migration[5.1]
  def change
    create_table :electronic_queues do |t|
      t.string :queue_name
      t.references :department, foreign_key: true, null: false
      t.integer :windows_count
      t.string :printer_address
      t.string :ipad_link
      t.string :tv_link
      t.boolean :enabled

      t.timestamps
    end

    add_index :electronic_queues, :ipad_link, unique: true
    add_index :electronic_queues, :tv_link, unique: true
  end
end
