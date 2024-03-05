class CreateJoinTableCardUser < ActiveRecord::Migration[5.1]
  def change
    create_join_table :kanban_cards, :users do |t|
      t.index [:kanban_card_id, :user_id]
      t.foreign_key :kanban_cards
      t.foreign_key :users
    end
  end
end
