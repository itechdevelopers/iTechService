class CreateViewExactDepartmentStockAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'view_exact_department_stock')
  end

  def down
    Ability.find_by(name: 'view_exact_department_stock')&.destroy
  end
end
