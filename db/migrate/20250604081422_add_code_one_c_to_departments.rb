class AddCodeOneCToDepartments < ActiveRecord::Migration[5.1]
  def change
    add_column :departments, :code_one_c, :string
  end
end
