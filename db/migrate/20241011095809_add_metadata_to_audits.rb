class AddMetadataToAudits < ActiveRecord::Migration[5.1]
  def change
    add_column :audits, :metadata, :jsonb, default: {}, null: false
    add_index :audits, :metadata, using: :gin
    add_index :audits, "(metadata->>'department_id')"
    add_index :audits, "(metadata->>'audit_type')"
  end
end
