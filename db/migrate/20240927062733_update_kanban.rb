class UpdateKanban < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_boards, :open_background_color, :string
    add_column :kanban_boards, :card_font_color, :string
    add_column :kanban_boards, :card_font_size, :integer
    add_column :kanban_boards, :open_card_font_size, :integer
  end
end
