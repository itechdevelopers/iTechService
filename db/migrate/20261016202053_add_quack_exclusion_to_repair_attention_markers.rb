class AddQuackExclusionToRepairAttentionMarkers < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_attention_markers, :quack_excluded_at, :datetime
    add_reference :repair_attention_markers, :quack_excluded_by, foreign_key: { to_table: :users }
  end
end
