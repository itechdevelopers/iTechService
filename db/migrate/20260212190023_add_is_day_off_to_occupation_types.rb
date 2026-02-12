class AddIsDayOffToOccupationTypes < ActiveRecord::Migration[5.1]
  def change
    add_column :occupation_types, :is_day_off, :boolean, default: false, null: false
  end
end
