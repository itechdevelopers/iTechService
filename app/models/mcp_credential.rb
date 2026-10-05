# frozen_string_literal: true
require 'digest'
require 'securerandom'

class McpCredential < ApplicationRecord
  belongs_to :user
  def self.issue!(kind:, user:, client_id:, resource:, scope:, **attributes)
    raw = SecureRandom.urlsafe_base64(48)
    create!(attributes.merge(kind: kind, user: user, client_id: client_id, resource: resource,
                             scope: scope, family_id: attributes[:family_id] || SecureRandom.uuid, digest: Digest::SHA256.hexdigest(raw)))
    raw
  end

  def self.lookup(raw, kind)
    return if raw.to_s.empty? || raw.to_s.bytesize > 512
    find_by(digest: Digest::SHA256.hexdigest(raw), kind: kind)
  end

  def usable?
    revoked_at.nil? && expires_at > Time.current && !user.is_fired? &&
      client_id == Mcp::Configuration.client_id && resource == Mcp::Configuration.resource
  end
end
