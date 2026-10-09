class CreateGreenApiInstances < ActiveRecord::Migration[5.1]
  def change
    create_table :green_api_instances do |t|
      t.string :channel, null: false
      t.string :api_url, null: false
      t.string :media_url
      t.string :id_instance, null: false
      t.text :encrypted_api_token, null: false
      t.text :encrypted_webhook_token, null: false
      t.references :updated_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :green_api_instances, :channel, unique: true
  end
end
