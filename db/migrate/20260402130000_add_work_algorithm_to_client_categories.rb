class AddWorkAlgorithmToClientCategories < ActiveRecord::Migration[5.1]
  def change
    add_column :client_categories, :work_algorithm, :text
  end
end
