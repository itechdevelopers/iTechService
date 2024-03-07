class AddAllowedUserIdsToBoards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_boards, :allowed_user_ids, :integer, array: true, default: []
    add_index :kanban_boards, :allowed_user_ids
  end
end
