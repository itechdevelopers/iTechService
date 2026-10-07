# frozen_string_literal: true

require 'digest'
require 'securerandom'

# A separate, expiring credential for one MCP connection; legacy API tokens remain unchanged.
class McpApiToken < ApplicationRecord
  belongs_to :user
  validates :token_digest, :expires_at, presence: true
  validates :token_digest, uniqueness: true

  def self.issue(user)
    token = "mcp_#{SecureRandom.hex(32)}"
    create!(user: user, token_digest: Digest::SHA256.hexdigest(token), expires_at: 1.hour.from_now)
    token
  end

  def self.authenticate(token)
    record = find_by(token_digest: Digest::SHA256.hexdigest(token.to_s), revoked_at: nil)
    return unless record && record.expires_at > Time.current
    record.user unless record.user.is_fired?
  end

  def self.revoke(token)
    where(token_digest: Digest::SHA256.hexdigest(token.to_s), revoked_at: nil).update_all(revoked_at: Time.current)
  end
end
