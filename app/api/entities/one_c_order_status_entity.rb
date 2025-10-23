class Entities::OneCOrderStatusEntity < Grape::Entity
  expose :id, documentation: { type: 'Integer', desc: 'Order ID in iTechService' }
  expose :number, documentation: { type: 'String', desc: 'Order number (UUID)' }

  expose :status, documentation: { type: 'String', desc: 'Current order status (in Cyrillic)' } do |order, _|
    # Translate English status to Cyrillic for 1C
    OrderStatusTranslator.to_cyrillic(order.status, type: :status) || order.status
  end

  expose :archive_reason, documentation: { type: 'String', desc: 'Reason for archival (in Cyrillic)' } do |order, _|
    # Translate English archive reason to Cyrillic for 1C
    if order.archive_reason.present?
      OrderStatusTranslator.to_cyrillic(order.archive_reason, type: :archive_reason) || order.archive_reason
    end
  end

  expose :archive_comment, documentation: { type: 'String', desc: 'Additional archive comment' }
  expose :updated_at, documentation: { type: 'DateTime', desc: 'Last update timestamp' }

  expose :external_id, documentation: { type: 'String', desc: '1C external ID' } do |order, _|
    order.one_c_sync&.external_id
  end

  expose :sync_status, documentation: { type: 'String', desc: '1C sync status' } do |order, _|
    order.one_c_sync&.sync_status || 'not_synced'
  end

  expose :sync_updated_at, documentation: { type: 'DateTime', desc: 'Last sync timestamp' } do |order, _|
    order.one_c_sync&.updated_at
  end

  expose :department, documentation: { type: 'String', desc: 'Department name' } do |order, _|
    order.department&.name
  end

  expose :object_kind, documentation: { type: 'String', desc: 'Order object type' }
  expose :object, documentation: { type: 'String', desc: 'Order object description' }
  expose :quantity, documentation: { type: 'Integer', desc: 'Order quantity' }
end