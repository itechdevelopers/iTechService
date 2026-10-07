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

  it 'lets an admin create one merit without a date and replays the same result' do
    actor = create(:user, role: 'admin')
    recipient = create(:user, role: 'technician', department: actor.department)
    headers = auth_headers(actor)
    body = { comment: 'За проверку', idempotency_key: 'merit-allowed' }

    post "/api/v1/employees/#{recipient.id}/merits", params: body, headers: headers
    expect(response).to have_http_status(:created)
    merit = Merit.find(JSON.parse(response.body).dig('merit', 'id'))
    expect(merit.recipient_id).to eq(recipient.id)
    expect(merit.issued_by_id).to eq(actor.id)
    expect(merit.date.to_date).to eq(Date.current)

    post "/api/v1/employees/#{recipient.id}/merits", params: body, headers: headers
    expect(response).to have_http_status(:created)
    expect(Merit.where(recipient_id: recipient.id, comment: body[:comment]).count).to eq(1)
  end

  it 'searches repair options from the existing model, price and spare-part records' do
    user = create(:user, role: 'technician')
    product_group = create(:product_group, repair_group: create(:repair_group))
    product = create(
      :product,
      name: 'iPhone 16 Pro Max',
      product_group: product_group,
      product_category: product_group.product_category
    )
    service = RepairService.create!(repair_group: create(:repair_group), name: 'Замена экрана')
    product.repair_services << service
    spare_group = create(:spare_part_product_group, repair_group: create(:repair_group))
    spare_product = create(
      :product,
      :spare_part,
      name: 'OLED экран',
      product_group: spare_group,
      product_category: spare_group.product_category
    )
    service.spare_parts.create!(product: spare_product, quantity: 1)
    RepairPrice.create!(repair_service: service, department: user.department, value: 18_000)

    get '/api/v1/repairs/options',
        params: { model_query: 'iPhone 16', repair_query: 'экран' }, headers: auth_headers(user)

    expect(response).to have_http_status(:success)
    payload = JSON.parse(response.body)
    expect(payload['options'].map { |option| option['repair_service_id'] }).to include(service.id)
    expect(payload['options'].first['client_price']).to eq('18000.0')
  end

  it 'changes an unlock workflow status and appends a separate comment idempotently' do
    user = create(:user, role: 'technician')
    client = create(:client, surname: 'Клиент', department: user.department)
    item_group = create(:product_group, repair_group: create(:repair_group))
    item_product = create(:product, product_group: item_group, product_category: item_group.product_category)
    item = create(:item, product: item_product)
    unlock = DeviceUnlockRequest.create!(client: client, item: item, user: user,
                                         department: user.department, reason: 'Проверить заявку')
    headers = auth_headers(user)

    patch "/api/v1/unlock_requests/#{unlock.id}/status",
          params: { status: 'approved', idempotency_key: 'unlock-status-1' }, headers: headers
    expect(response).to have_http_status(:success)
    expect(unlock.reload.status).to eq('approved')

    body = { content: 'Согласовано с клиентом', idempotency_key: 'unlock-comment-1' }
    post "/api/v1/unlock_requests/#{unlock.id}/comments", params: body, headers: headers
    post "/api/v1/unlock_requests/#{unlock.id}/comments", params: body, headers: headers
    expect(response).to have_http_status(:success)
    expect(unlock.comments.reload.where(content: body[:content]).count).to eq(1)
  end
end
# rubocop:enable Metrics/BlockLength
