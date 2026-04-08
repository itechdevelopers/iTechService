# frozen_string_literal: true

class CreateStoreClosingGroups < ActiveRecord::Migration[5.1]
  def change
    create_table :store_closing_groups do |t|
      t.references :department, foreign_key: true, null: false, index: false
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :store_closing_groups, :department_id, unique: true
  end
end
