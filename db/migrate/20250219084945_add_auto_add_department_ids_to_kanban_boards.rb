class AddAutoAddDepartmentIdsToKanbanBoards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_boards, :auto_add_department_ids, :integer, array: true, default: []
    add_index :kanban_boards, :auto_add_department_ids, using: :gin
  end
end
