class AddPhoneDirectoryAssignments < ActiveRecord::Migration[5.1]
  def change
    add_column :phone_labels, :group_name, :string
    add_index :phone_labels, :group_name
    add_reference :phone_labels, :department, foreign_key: true
    add_reference :phone_labels, :user, foreign_key: true
  end
end
