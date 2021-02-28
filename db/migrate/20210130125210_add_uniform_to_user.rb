class AddUniformToUser < ActiveRecord::Migration
  def change
    add_column :users, :uniform_sex, :string
    add_column :users, :uniform_size, :string
  end
end
