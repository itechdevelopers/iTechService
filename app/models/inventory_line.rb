# frozen_string_literal: true

# Строка ревизии. Привязана к item, а не к product: остаток физически лежит на
# StoreItem(item_id, store_id), и deduction_items оперируют тем же item_id —
# так строка ложится на порождаемый документ один-в-один.
class InventoryLine < ApplicationRecord
  belongs_to :inventory
  belongs_to :item
  belongs_to :counted_by, class_name: 'User', optional: true

  # nil — расхождение ещё не разобрано товароведом
  enum resolution: { accepted: 0, recounted: 1 }, _prefix: :resolution

  delegate :product, :code, to: :item, allow_nil: true

  scope :ordered, -> { order(:position) }
  scope :counted, -> { where.not(counted_quantity: nil) }
  scope :uncounted, -> { where(counted_quantity: nil) }
  scope :requested_for_recount, -> { where(recount_requested: true) }

  validates :item, :position, presence: true
  validates :counted_quantity, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, allow_nil: true
  }

  # Имя на момент формирования списка — актуальное имя товара берём только как
  # запасной вариант для строк, созданных до появления снимков.
  def name
    snapshot_name.presence || item&.name
  end

  def counted?
    !counted_quantity.nil?
  end

  # Расхождение считаем только у заполненных строк: пустая строка — это «ещё не
  # считали», а не «нашли ноль».
  def discrepancy?
    counted? && counted_quantity != expected_quantity
  end

  # Положительное — излишек, отрицательное — недостача.
  def difference
    return nil unless counted?

    counted_quantity - (expected_quantity || 0)
  end
end
