# frozen_string_literal: true

# Связь ревизии с порождённым ею складским документом (акт списания и т.п.).
# Полиморфная, чтобы не добавлять inventory_id в чужие таблицы документов.
class InventoryDocument < ApplicationRecord
  belongs_to :inventory
  belongs_to :document, polymorphic: true
end
