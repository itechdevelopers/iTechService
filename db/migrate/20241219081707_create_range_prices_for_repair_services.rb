class CreateRangePricesForRepairServices < ActiveRecord::Migration[5.1]
  def up
    add_column :repair_services, :has_range_prices, :boolean, default: false
    add_column :repair_prices, :is_range_price, :boolean, default: false
    add_column :repair_prices, :value_from, :decimal
    add_column :repair_prices, :value_to, :decimal
  end

  def down
    remove_column :repair_services, :has_range_prices
    remove_column :repair_prices, :is_range_price
    remove_column :repair_prices, :value_from
    remove_column :repair_prices, :value_to
  end
end
