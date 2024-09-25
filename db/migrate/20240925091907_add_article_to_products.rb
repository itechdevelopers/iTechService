class AddArticleToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :article, :string, null: true
    add_index :products, :article, unique: true
  end
end
