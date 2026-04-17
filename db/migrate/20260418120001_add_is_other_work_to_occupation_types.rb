class AddIsOtherWorkToOccupationTypes < ActiveRecord::Migration[5.1]
  def change
    add_column :occupation_types, :is_other_work, :boolean, default: false, null: false
  end
end
