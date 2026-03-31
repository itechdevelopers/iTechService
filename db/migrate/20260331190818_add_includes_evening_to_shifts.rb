class AddIncludesEveningToShifts < ActiveRecord::Migration[5.1]
  def change
    add_column :shifts, :includes_evening, :boolean, default: false
  end
end
