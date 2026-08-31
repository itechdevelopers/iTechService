class NormalizeSparePartsQuantity < ActiveRecord::Migration[5.1]
  def up
    SparePart.where.not(quantity: 1).update_all(quantity: 1)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
