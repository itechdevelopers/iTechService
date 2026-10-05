class CreateMcpCredentialsAndWrites < ActiveRecord::Migration[5.1]
  def change
    create_table :mcp_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :family_id, null: false
      t.string :digest, null: false
      t.string :client_id, null: false
      t.string :resource, null: false
      t.string :scope, null: false
      t.string :redirect_uri
      t.string :code_challenge
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :mcp_credentials, :digest, unique: true
    add_index :mcp_credentials, :family_id
    create_table :mcp_writes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :request_key, null: false
      t.string :fingerprint, null: false
      t.string :tool, null: false
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :outcome, null: false, default: 'started'
      t.jsonb :result, null: false, default: {}
      t.jsonb :outbox, null: false, default: []
      t.datetime :dispatched_at
      t.timestamps
    end
    add_index :mcp_writes, [:user_id, :request_key], unique: true
  end
end
