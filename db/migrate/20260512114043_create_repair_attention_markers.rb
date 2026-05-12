class CreateRepairAttentionMarkers < ActiveRecord::Migration[5.1]
  def change
    create_table :repair_attention_markers do |t|
      t.references :service_job, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :status_at_view, foreign_key: { to_table: :repair_statuses }
      t.datetime :viewed_at, null: false
      t.string :dismiss_token, null: false
      t.string :start_token, null: false
      t.datetime :notified_at
      t.datetime :escalated_at
      t.datetime :processed_at
      t.string :processed_action
      t.references :processed_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :repair_attention_markers, :dismiss_token, unique: true
    add_index :repair_attention_markers, :start_token, unique: true
    add_index :repair_attention_markers, %i[service_job_id processed_at],
              name: 'idx_ram_on_sj_and_processed_at'
    add_index :repair_attention_markers, %i[user_id service_job_id viewed_at],
              name: 'idx_ram_on_user_sj_viewed_at'
  end
end
