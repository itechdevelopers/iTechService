class AddLogoToCarriers < ActiveRecord::Migration[5.1]
  def change
    add_column :carriers, :logo, :string
  end
end
