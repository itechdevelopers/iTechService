class AddAppearanceToKanbanBoards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_boards, :card_white_background, :boolean, default: false, null: false
    add_column :kanban_boards, :background_image, :string
  end
end
