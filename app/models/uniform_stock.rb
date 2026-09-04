# frozen_string_literal: true

# Строка склада = пара «вид формы + размер». quantity — свободный остаток, который
# двигают приход, списание и выдача.
class UniformStock < ApplicationRecord
  # Размеры сортируются по порядку из SIZES, а не по алфавиту: иначе «2xl» окажется
  # раньше «l». array_position — постгресовая функция, индекс элемента в массиве.
  ORDER_SQL = "array_position(ARRAY[#{UniformKind::SIZES.map { |s| "'#{s}'" }.join(',')}]::text[], uniform_stocks.size)"

  belongs_to :uniform_kind, inverse_of: :uniform_stocks

  has_many :uniform_operation_lines

  validates :size, presence: true, inclusion: { in: UniformKind::SIZES }
  validates :size, uniqueness: { scope: :uniform_kind_id }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(Arel.sql(ORDER_SQL)) }

  def label
    size.upcase
  end

  # Размер можно убрать из вида, только если по нему нечего терять: ни остатка,
  # ни движений.
  def removable?
    quantity.to_i.zero? && uniform_operation_lines.none?
  end
end
