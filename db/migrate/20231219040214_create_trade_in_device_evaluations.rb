class CreateTradeInDeviceEvaluations < ActiveRecord::Migration[5.1]
  def change
    create_table :trade_in_device_evaluations do |t|
      t.string :name
      t.references :product_group, foreign_key: true
      t.decimal :min_value
      t.decimal :max_value
      t.decimal :lack_of_kit

      t.timestamps
    end
  end
end
