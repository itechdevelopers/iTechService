class MigrateExistingOneCSyncedOrders < ActiveRecord::Migration[5.1]
  def up
    # Process in batches to handle large datasets efficiently
    Order.where(one_c_synced: true).find_each(batch_size: 1000) do |order|
      # Create OrderExternalSync record for successfully synced orders
      OrderExternalSync.create!(
        order: order,
        external_system: :one_c,
        sync_status: :synced,
        external_id: order.number, # Use order number as external_id
        sync_attempts: 1,
        last_attempt_at: order.updated_at,
        attention_required: requires_article_attention?(order),
        sync_notes: "Migrated from one_c_synced field"
      )
    end
    
    # Handle orders that were not synced (one_c_synced: false)
    Order.where(one_c_synced: false).find_each(batch_size: 1000) do |order|
      OrderExternalSync.create!(
        order: order,
        external_system: :one_c,
        sync_status: :failed,
        external_id: nil,
        sync_attempts: 1,
        last_attempt_at: order.updated_at,
        last_error: "Failed to sync during order creation",
        attention_required: requires_article_attention?(order),
        sync_notes: "Migrated from one_c_synced field - originally failed"
      )
    end
  end
  
  def down
    # Remove all migrated records
    OrderExternalSync.where(sync_notes: "Migrated from one_c_synced field").destroy_all
    OrderExternalSync.where(sync_notes: "Migrated from one_c_synced field - originally failed").destroy_all
  end
  
  private
  
  def requires_article_attention?(order)
    order.object_kind == 'device' && (order.article.blank? || order.article.strip.blank?)
  end
end
