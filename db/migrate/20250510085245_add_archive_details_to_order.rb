class AddArchiveDetailsToOrder < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :archive_reason, :string
    add_column :orders, :archive_comment, :text
  end
end
