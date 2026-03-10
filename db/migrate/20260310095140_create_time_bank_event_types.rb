# frozen_string_literal: true

class CreateTimeBankEventTypes < ActiveRecord::Migration[5.1]
  def change
    create_table :time_bank_event_types do |t|
      t.string :name, null: false
      t.string :direction, null: false, default: 'both'
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
