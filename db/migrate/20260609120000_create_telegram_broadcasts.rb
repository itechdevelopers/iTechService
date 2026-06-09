class CreateTelegramBroadcasts < ActiveRecord::Migration[5.1]
  def change
    create_table :telegram_broadcasts do |t|
      t.references :telegram_chat, foreign_key: true, null: false
      t.string  :title, null: false
      t.integer :schedule_type, null: false, default: 0
      t.integer :day_of_month
      t.integer :interval_days
      t.integer :selection_mode, null: false, default: 0
      t.integer :last_variant_index, null: false, default: 0
      t.date    :last_sent_on
      t.boolean :active, null: false, default: true
      t.string  :image

      t.timestamps
    end

    create_table :telegram_broadcast_variants do |t|
      t.references :telegram_broadcast, foreign_key: true, null: false
      t.text :body, null: false

      t.timestamps
    end
  end
end
