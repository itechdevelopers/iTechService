# frozen_string_literal: true

require 'rails_helper'

RSpec.describe McpIdempotencyKey, type: :model do
  it 'isolates the same key by user and operation' do
    first = create(:user)
    second = create(:user)
    create(:mcp_idempotency_key, user: first, operation: 'add_client_note', key: 'same')

    expect(build(:mcp_idempotency_key, user: first, operation: 'add_client_note', key: 'same')).not_to be_valid
    expect(build(:mcp_idempotency_key, user: first, operation: 'add_fault', key: 'same')).to be_valid
    expect(build(:mcp_idempotency_key, user: second, operation: 'add_client_note', key: 'same')).to be_valid
  end
end
