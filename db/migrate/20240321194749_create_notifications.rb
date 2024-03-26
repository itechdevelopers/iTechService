class CreateNotifications < ActiveRecord::Migration[5.1]
  def change
    create_table :notifications do |t|
      t.references :referenceable, polymorphic: true
      t.references :user, foreign_key: true, null: false
      t.string :url, null: false
      t.datetime :closed_at
      t.text :message

      t.timestamps
    end
  end
end
