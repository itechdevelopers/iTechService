class UpdateProductGroups < ActiveRecord::Migration[5.1]
  def change
    add_column :product_groups, :trademark, :string
    add_column :product_groups, :product_line, :string
  end
end
