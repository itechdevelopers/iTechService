class AddWorkPhoneToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :work_phone, :string
  end
end
