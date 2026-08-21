class AddExternalGuidToOrderExternalSyncs < ActiveRecord::Migration[5.1]
  def change
    add_column :order_external_syncs, :external_guid, :string

    # Partial unique index: a 1C document GUID is globally unique, so a botched
    # backfill must fail loudly instead of silently binding two orders together.
    add_index :order_external_syncs, :external_guid,
              unique: true,
              where: 'external_guid IS NOT NULL',
              name: 'index_order_external_syncs_on_external_guid'
  end
end
