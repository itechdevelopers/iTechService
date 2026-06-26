class AddArchivedToKanbanBoards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_boards, :archived, :boolean, default: false, null: false
    add_index :kanban_boards, :archived
  end
end
