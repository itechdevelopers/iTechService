class AddOptionValuesToEvaluations < ActiveRecord::Migration[5.1]
  def change
    add_column :trade_in_device_evaluations, :option_values, :integer, array: true, default: []
  end
end
