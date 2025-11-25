class CreateServiceConditions < ActiveRecord::Migration[5.1]
  def change
    create_table :service_conditions do |t|
      t.string :number
      t.text :content
      t.integer :position

      t.timestamps
    end
  end
end
