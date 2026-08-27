# frozen_string_literal: true

# Куда ушёл излишек по строке. Склад выбирается в момент приёма — у каждого
# филиала он может быть свой, поэтому храним на строке, а не в настройках.
class AddSurplusStoreToInventoryLines < ActiveRecord::Migration[5.1]
  def change
    add_reference :inventory_lines, :surplus_store, foreign_key: { to_table: :stores }
  end
end
