# frozen_string_literal: true

class CreateUserPauses < ActiveRecord::Migration[5.1]
  def change
    create_table :user_pauses do |t|
      t.references :user, foreign_key: true, null: false
      t.datetime :paused_at, null: false
      t.datetime :resumed_at
      t.string :reason

      t.timestamps
    end

    add_index :user_pauses, :paused_at
  end
end
