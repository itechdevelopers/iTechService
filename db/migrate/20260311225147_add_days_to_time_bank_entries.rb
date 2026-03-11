class AddDaysToTimeBankEntries < ActiveRecord::Migration[5.1]
  def change
    add_column :time_bank_entries, :days, :integer, null: false, default: 0
  end
end
