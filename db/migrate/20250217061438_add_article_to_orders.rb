class AddArticleToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :article, :string
  end
end
