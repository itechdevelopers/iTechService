class AddNameToKanbanCards < ActiveRecord::Migration[5.1]
  def up
    add_column :kanban_cards, :name, :string

    Kanban::Card.reset_column_information

    Kanban::Card.find_each do |card|
      name = card.content.length <= 200 ? card.content : '-'
      card.update_column(:name, name)
    end
  end

  def down
    remove_column :kanban_cards, :name
  end
end
