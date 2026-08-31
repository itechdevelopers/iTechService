class SetSparePartsQuantityDefault < ActiveRecord::Migration[5.1]
  def up
    change_column_default :spare_parts, :quantity, 1
    change_column_null :spare_parts, :quantity, false, 1
  end

  def down
    change_column_null :spare_parts, :quantity, true
    change_column_default :spare_parts, :quantity, nil
  end
end
