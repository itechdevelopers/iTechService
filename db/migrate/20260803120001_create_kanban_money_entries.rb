class CreateKanbanMoneyEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :kanban_money_entries do |t|
      t.references :card, null: false, foreign_key: {to_table: :kanban_cards}
      t.string :reason, null: false
      t.integer :amount, null: false

      t.timestamps
    end
  end
end
