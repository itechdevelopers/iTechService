# frozen_string_literal: true

class CreateStoreClosingMemberships < ActiveRecord::Migration[5.1]
  def change
    create_table :store_closing_memberships do |t|
      t.references :store_closing_group, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.integer :position

      t.timestamps
    end

    add_index :store_closing_memberships, %i[store_closing_group_id user_id],
              unique: true, name: 'index_store_closing_memberships_uniqueness'
  end
end
