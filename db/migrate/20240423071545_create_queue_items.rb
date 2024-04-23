class CreateQueueItems < ActiveRecord::Migration[5.1]
  def change
    create_table :queue_items do |t|
      t.string :title
      t.text :annotation
      t.boolean :phone_input
      t.string :windows
      t.integer :task_duration
      t.integer :max_wait_time
      t.text :additional_info
      t.string :ticket_abbreviation
      t.references :electronic_queue, foreign_key: true, null: false
      t.integer :position, null: false, default: 0
      t.string :ancestry
      t.integer :ancestry_depth, default: 0

      t.timestamps
    end
  end
end
