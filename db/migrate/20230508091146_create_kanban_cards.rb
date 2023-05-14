class CreateKanbanCards < ActiveRecord::Migration[5.1]
  def change
    create_table :kanban_cards do |t|
      t.text :content
      t.references :author, null: false, foreign_key: {to_table: :users}, index: false
      t.references :column, null: false, foreign_key: {to_table: :kanban_columns}
      t.integer :position

      t.timestamps
    end
  end
end
