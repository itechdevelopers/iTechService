# frozen_string_literal: true

# Stores retry results for MCP write operations.
class McpIdempotencyKey < ApplicationRecord
  belongs_to :user

  validates :key, :operation, :response_json, presence: true
  validates :key, length: { maximum: 200 }
  validates :operation, length: { maximum: 100 }
end
