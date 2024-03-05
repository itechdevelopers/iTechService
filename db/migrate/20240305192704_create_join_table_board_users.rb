class CreateJoinTableBoardUsers < ActiveRecord::Migration[5.1]
  def change
    create_join_table :kanban_boards, :users do |t|
      t.index [:kanban_board_id, :user_id]
      t.foreign_key :kanban_boards
      t.foreign_key :users
    end
  end
end
