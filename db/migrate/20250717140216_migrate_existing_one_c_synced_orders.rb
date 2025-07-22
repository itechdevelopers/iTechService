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
    
    # NOTE: Orders with one_c_synced = false are intentionally ignored
    # They will get OrderExternalSync records created when they actually need sync
  end
  
  def down
    # Remove all migrated records (only synced records since we don't create failed ones)
    OrderExternalSync.where(sync_notes: "Migrated from one_c_synced field").destroy_all
  end
  
  private
  
  def requires_article_attention?(order)
    order.object_kind == 'device' && (order.article.blank? || order.article.strip.blank?)
  end
end
