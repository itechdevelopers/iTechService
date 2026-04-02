class AddAuditToClientCharacteristics < ActiveRecord::Migration[5.1]
  def change
    add_reference :client_characteristics, :set_by_user, foreign_key: { to_table: :users }
    add_column :client_characteristics, :set_at, :datetime
  end
end
