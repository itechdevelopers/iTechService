class AddOrganizationFieldsToPayments < ActiveRecord::Migration[5.1]
  def change
    add_column :payments, :organization_name, :string
    add_column :payments, :payment_details, :text
  end
end
