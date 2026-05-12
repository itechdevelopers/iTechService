class CreateRepairStatusSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :repair_status_settings do |t|
      t.integer :attention_timeout_seconds,  null: false, default: 300
      t.integer :escalation_timeout_seconds, null: false, default: 3600
      t.timestamps
    end
  end
end
