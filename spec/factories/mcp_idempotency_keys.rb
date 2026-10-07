# frozen_string_literal: true

require 'digest'

FactoryGirl.define do
  factory :mcp_idempotency_key do
    association :user
    operation 'add_client_note'
    sequence(:key) { |n| "mcp-key-#{n}" }
    payload_digest { Digest::SHA256.hexdigest(key) }
    response_json '{"success":true}'
  end
end
