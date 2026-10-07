# frozen_string_literal: true

class CreateMcpApiTokens < ActiveRecord::Migration[5.1]
  def change
    create_table :mcp_api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps null: false
    end
    add_index :mcp_api_tokens, :token_digest, unique: true
    add_index :mcp_api_tokens, :expires_at
  end
end
