class CreateReportPermissions < ActiveRecord::Migration[5.1]
  def change
    create_table :report_permissions do |t|
      t.references :user, foreign_key: true, null: false
      t.references :report_card, foreign_key: true, null: false
      t.timestamps
    end
    
    add_index :report_permissions, [:user_id, :report_card_id], unique: true
  end
end
