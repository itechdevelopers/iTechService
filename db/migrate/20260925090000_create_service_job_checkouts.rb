class CreateServiceJobCheckouts < ActiveRecord::Migration[5.1]
  def change
    create_table :service_job_checkouts do |t|
      t.references :service_job, null: false, foreign_key: true
      t.string :uid, null: false
      t.integer :state, null: false, default: 0
      t.references :initiator, foreign_key: { to_table: :users }
      t.decimal :expected_total, precision: 10, scale: 2, null: false, default: 0
      t.decimal :paid_total, precision: 10, scale: 2
      t.jsonb :items_snapshot, null: false, default: []
      t.string :check_number
      t.string :check_guid
      t.jsonb :payments, null: false, default: []
      t.string :cashier_name
      t.boolean :manual, null: false, default: false
      t.datetime :matched_at
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.boolean :parts_review_required, null: false, default: false
      t.datetime :sent_at
      t.datetime :paid_at
      t.datetime :archived_at
      t.datetime :cancelled_at
      t.string :cancel_reason
      t.string :not_archived_reason
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.timestamps
    end

    add_index :service_job_checkouts, :uid, unique: true
    add_index :service_job_checkouts, :state
    add_index :service_job_checkouts, :check_number
  end
end
