# frozen_string_literal: true

# Что именно считать в ревизии: выбранные группы каталога и отдельные позиции.
# Полиморфно, потому что заказчик выбирает и целые модели («все айфоны»,
# «iPhone 17 Pro Max»), и точечные запчасти внутри модели.
#
# Хранится ОТДЕЛЬНО от inventory_lines: выбор — это правило разворота, а строки
# — его результат, который товаровед потом правит руками (удаляет лишние,
# добавляет забытые). Смешав их, мы бы теряли правки при каждой пересборке.
class CreateInventorySelections < ActiveRecord::Migration[5.1]
  def change
    create_table :inventory_selections do |t|
      t.references :inventory, foreign_key: true, null: false
      t.references :selectable, polymorphic: true, null: false,
                   index: { name: 'idx_inventory_selections_on_selectable' }

      t.timestamps
    end

    add_index :inventory_selections, %i[inventory_id selectable_type selectable_id],
              unique: true, name: 'idx_inventory_selections_unique'
  end
end
