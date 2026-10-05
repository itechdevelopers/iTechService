# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'AIS MCP Rails API' do
  def auth_headers(user)
    user.update_authentication_token
    { 'Authorization' => "Token token=#{user.reload.authentication_token}" }
  end

  it 'rejects an unauthenticated MCP API request' do
    get '/api/v1/clients/search', params: { query: 'test' }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'requires a non-empty search and authenticates as the supplied AIS user' do
    user = create(:user, role: 'technician')
    get '/api/v1/clients/search', params: { query: '' }, headers: auth_headers(user)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to eq('query is required')
  end

  it 'appends a client note once and rejects a reused key with changed payload' do
    user = create(:user, role: 'technician')
    client = create(
      :client,
      name: 'James',
      surname: 'Bond',
      category: 0,
      department: user.department,
      phone_number_checked: true
    )
    headers = auth_headers(user)
    body = { content: 'Предпочитает Telegram', idempotency_key: 'client-note-1' }

    post "/api/v1/clients/#{client.id}/notes", params: body, headers: headers
    expect(response).to have_http_status(:success)
    expect(client.comments.reload.where(content: body[:content]).count).to eq(1)

    post "/api/v1/clients/#{client.id}/notes", params: body, headers: headers
    expect(response).to have_http_status(:success)
    expect(client.comments.reload.where(content: body[:content]).count).to eq(1)

    post "/api/v1/clients/#{client.id}/notes", params: body.merge(content: 'Другой текст'), headers: headers
    expect(response).to have_http_status(:conflict)
    expect(client.comments.reload.count).to eq(1)
  end

  it 'enforces existing Merit and Fault permissions for the acting employee' do
    actor = create(:user, role: 'technician')
    recipient = create(:user, role: 'technician', department: actor.department)
    headers = auth_headers(actor)

    post "/api/v1/employees/#{recipient.id}/merits", params: {
      comment: 'За проверку', date: Date.current.iso8601, idempotency_key: 'merit-denied'
    }, headers: headers
    expect(response).to have_http_status(:forbidden)
    expect(Merit.where(recipient_id: recipient.id)).to be_empty

    kind = FaultKind.create!(name: 'Тестовая категория', is_permanent: true)
    post "/api/v1/employees/#{recipient.id}/faults", params: {
      kind_id: kind.id, comment: 'Причина', date: Date.current.iso8601, idempotency_key: 'fault-denied'
    }, headers: headers
    expect(response).to have_http_status(:forbidden)
    expect(Fault.where(causer_id: recipient.id)).to be_empty
  end
end
# rubocop:enable Metrics/BlockLength
