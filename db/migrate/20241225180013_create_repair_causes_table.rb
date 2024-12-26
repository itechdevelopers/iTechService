class CreateRepairCausesTable < ActiveRecord::Migration[5.1]
  def change
    create_table :repair_cause_groups do |t|
      t.string :title
      t.timestamps
    end
    
    create_table :repair_causes do |t|
      t.string :title
      t.belongs_to :repair_cause_group
      t.timestamps
    end

    create_table :repair_causes_services do |t|
      t.belongs_to :repair_cause
      t.belongs_to :repair_service
      t.timestamps
    end
  end
end
