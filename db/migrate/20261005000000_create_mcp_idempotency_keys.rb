# frozen_string_literal: true

# Creates retry protection records for MCP write operations.
class CreateMcpIdempotencyKeys < ActiveRecord::Migration
  def change
    create_table :mcp_idempotency_keys do |t|
      t.string :key, null: false
      t.string :operation, null: false
      t.integer :user_id, null: false
      t.text :response_json, null: false
      t.timestamps null: false
    end

    add_index :mcp_idempotency_keys, %i[user_id key],
              name: 'index_mcp_idempotency_keys_on_user_and_key', unique: true
    add_index :mcp_idempotency_keys, :created_at
  end
end
