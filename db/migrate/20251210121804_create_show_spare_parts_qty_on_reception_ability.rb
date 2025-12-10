# frozen_string_literal: true

class CreateShowSparePartsQtyOnReceptionAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'show_spare_parts_qty_on_reception')
  end

  def down
    Ability.find_by(name: 'show_spare_parts_qty_on_reception')&.destroy
  end
end
