class AddPhotosToKanbanCards < ActiveRecord::Migration[5.1]
  def change
    add_column :kanban_cards, :photos, :string, array: true, default: []
  end
end
