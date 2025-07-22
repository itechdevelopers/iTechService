class CreateOrderExternalSyncs < ActiveRecord::Migration[5.1]
  def change
    create_table :order_external_syncs do |t|
      t.references :order, foreign_key: true, null: false, index: true
      t.integer :external_system, null: false, default: 0
      t.integer :sync_status, null: false, default: 0
      t.string :external_id, null: true
      t.integer :sync_attempts, null: false, default: 0
      t.datetime :last_attempt_at, null: true
      t.text :last_error, null: true
      t.boolean :attention_required, null: false, default: false
      t.text :sync_notes, null: true
      t.timestamps null: false
    end

    # Basic indices
    add_index :order_external_syncs, [:order_id, :external_system], unique: true, name: 'index_order_external_syncs_on_order_and_system'
    add_index :order_external_syncs, :sync_status
    add_index :order_external_syncs, :last_attempt_at
    add_index :order_external_syncs, :attention_required
  end
end
