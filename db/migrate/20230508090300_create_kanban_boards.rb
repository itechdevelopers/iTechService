class CreateKanbanBoards < ActiveRecord::Migration[5.1]
  def change
    create_table :kanban_boards do |t|
      t.string :name, null: false
      t.string :background

      t.timestamps
    end
  end
end
