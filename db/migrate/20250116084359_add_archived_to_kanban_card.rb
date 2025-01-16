class AddArchivedToKanbanCard < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_cards, :archived, :boolean, default: false
  end
end
