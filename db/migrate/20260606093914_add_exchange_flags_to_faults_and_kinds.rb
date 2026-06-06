class AddExchangeFlagsToFaultsAndKinds < ActiveRecord::Migration[5.1]
  def change
    add_column :fault_kinds, :exchangeable, :boolean, default: true, null: false

    add_column :faults, :exchanged, :boolean, default: false, null: false
    add_column :faults, :exchanged_at, :datetime
  end
end
