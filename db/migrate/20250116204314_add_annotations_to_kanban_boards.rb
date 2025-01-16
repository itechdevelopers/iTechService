class AddAnnotationsToKanbanBoards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_boards, :outer_annotation, :text
    add_column :kanban_boards, :inner_annotation, :text
  end
end
