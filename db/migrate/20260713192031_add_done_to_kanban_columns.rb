class AddDoneToKanbanColumns < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_columns, :done, :boolean, default: false, null: false
  end
end
