class AddWishHobbyToUser < ActiveRecord::Migration
  def change
    add_column :users, :wishlist, :string, array: true, default: []
    add_column :users, :hobby, :text
  end
end
