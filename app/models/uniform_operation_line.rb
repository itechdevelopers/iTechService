# frozen_string_literal: true

# Строка документа движения: сколько штук конкретной пары «вид + размер» прошло по
# документу. Знак не хранится — его даёт kind документа.
class UniformOperationLine < ApplicationRecord
  belongs_to :uniform_operation, inverse_of: :uniform_operation_lines
  belongs_to :uniform_stock

  has_one :uniform_kind, through: :uniform_stock

  validates :uniform_stock, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  # Остаток двигаем в той же транзакции, что и вставка строки. Именно в строке,
  # а не в документе: к моменту его after_create строки ещё не сохранены.
  after_create :apply_to_stock

  scope :for_stocks, ->(stock_ids) { where(uniform_stock_id: stock_ids) }
  scope :for_holder, ->(user) { joins(:uniform_operation).where(uniform_operations: { recipient_id: user.id }) }

  # Сколько числится за сотрудником по каждой позиции: выдали минус вернули минус
  # списали с рук. Колонкой не храним — иначе появится второй источник правды.
  def self.holder_balance(user)
    for_holder(user).holder_balance_by_stock
  end

  def self.holder_balance_by_stock
    joins(:uniform_operation)
      .group(:uniform_stock_id)
      .sum(Arel.sql("uniform_operation_lines.quantity * #{UniformOperation::HOLDER_SIGN_SQL}"))
  end

  def self.quantity_by_stock(kinds)
    joins(:uniform_operation)
      .where(uniform_operations: { kind: kinds })
      .group(:uniform_stock_id)
      .sum(:quantity)
  end

  private

  def apply_to_stock
    delta = uniform_operation.stock_sign * quantity
    uniform_stock.increment!(:quantity, delta) unless delta.zero?
  end
end
