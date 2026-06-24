class CreateTelegramBroadcastImages < ActiveRecord::Migration[5.1]
  def change
    create_table :telegram_broadcast_images do |t|
      t.references :telegram_broadcast, null: false, foreign_key: true, index: true
      t.string :file

      t.timestamps
    end

    # Курсор для in_order-ротации картинок — близнец last_variant_index.
    add_column :telegram_broadcasts, :last_image_index, :integer, default: 0, null: false
  end
end
