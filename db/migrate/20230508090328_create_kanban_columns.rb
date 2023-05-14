class CreateKanbanColumns < ActiveRecord::Migration[5.1]
  def change
    create_table :kanban_columns do |t|
      t.string :name, null: false
      t.references :board, null: false, foreign_key: {to_table: :kanban_boards}
      t.integer :position

      t.timestamps
    end
  end
end
