class AddAvailableForTradeInToProductGroup < ActiveRecord::Migration[5.1]
  def change
    add_column :product_groups, :available_for_trade_in, :boolean
  end
end
