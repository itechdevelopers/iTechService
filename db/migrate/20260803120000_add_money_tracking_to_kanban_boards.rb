class AddMoneyTrackingToKanbanBoards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_boards, :money_tracking, :boolean, default: false, null: false
  end
end
