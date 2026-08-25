# frozen_string_literal: true

# Элемент выбора «что считать»: группа каталога или отдельный продукт.
class InventorySelection < ApplicationRecord
  belongs_to :inventory
  belongs_to :selectable, polymorphic: true

  scope :groups, -> { where(selectable_type: 'ProductGroup') }
  scope :products, -> { where(selectable_type: 'Product') }
end
