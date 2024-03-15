class AddDeadlinesToKanbanCards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_cards, :deadline, :date
  end
end
