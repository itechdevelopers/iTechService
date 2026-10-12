class AddLiveCallHistory < ActiveRecord::Migration[5.1]
  def change
    add_column :phone_calls, :live_updated_at, :datetime
    add_column :phone_calls, :finalized_at, :datetime
    reversible do |dir|
      dir.up do
        execute "UPDATE phone_calls SET finalized_at = updated_at WHERE status IN ('answered', 'missed', 'busy', 'failed')"
      end
    end
    add_column :phone_calls, :legs, :jsonb, null: false, default: []
    add_index :phone_calls, :legs, using: :gin
    create_table :telephony_sync_states do |t|
      t.string :source, null: false
      t.datetime :observed_at, null: false
      t.boolean :connected, null: false, default: false
      t.timestamps
    end
    add_index :telephony_sync_states, :source, unique: true
  end
end
