# frozen_string_literal: true

# Документ движения формы: приход, списание со склада, выдача сотруднику, возврат
# от сотрудника и списание с сотрудника. Один документ — несколько строк по парам
# «вид + размер», направление задаёт kind, а не знак количества.
class UniformOperation < ApplicationRecord
  # Как операция двигает свободный остаток склада и то, что числится за сотрудником.
  # Списание с сотрудника склада не касается: эта форма на складе и не лежала.
  STOCK_SIGN = {
    'receipt' => 1, 'return_from_user' => 1,
    'write_off' => -1, 'issue' => -1,
    'write_off_from_user' => 0
  }.freeze

  HOLDER_SIGN = {
    'issue' => 1,
    'return_from_user' => -1, 'write_off_from_user' => -1,
    'receipt' => 0, 'write_off' => 0
  }.freeze

  KINDS = STOCK_SIGN.keys.freeze
  WRITE_OFF_KINDS = %w[write_off write_off_from_user].freeze
  RECIPIENT_KINDS = HOLDER_SIGN.reject { |_kind, sign| sign.zero? }.keys.freeze

  # Тот же HOLDER_SIGN, но для агрегатов: «сколько на сотрудниках» считается одним
  # GROUP BY, а не перебором документов в Ruby.
  HOLDER_SIGN_SQL = "CASE uniform_operations.kind " \
                    "#{HOLDER_SIGN.map { |kind, sign| "WHEN '#{kind}' THEN #{sign}" }.join(' ')} ELSE 0 END".freeze

  belongs_to :author, class_name: 'User'
  # Сотрудник есть не у всякой операции: у прихода и складского списания его нет,
  # поэтому обязательность задаётся ниже по kind, а не самой связью.
  belongs_to :recipient, class_name: 'User', optional: true

  has_many :uniform_operation_lines, inverse_of: :uniform_operation, dependent: :destroy
  has_many :uniform_stocks, through: :uniform_operation_lines

  # Строки без количества — это неотмеченные размеры в форме, а не ошибка ввода.
  accepts_nested_attributes_for :uniform_operation_lines,
                                reject_if: ->(attrs) { attrs[:quantity].to_i.zero? }

  validates :kind, inclusion: { in: KINDS }
  validates :performed_on, presence: true
  validates :recipient, presence: true, if: :recipient_required?
  validates :comment, presence: true, if: :comment_required?
  validate :any_lines
  validate :stock_available, on: :create
  validate :holder_has_enough, on: :create

  scope :recent, -> { order(performed_on: :desc, created_at: :desc) }
  scope :of_kind, ->(kinds) { where(kind: kinds) }

  def stock_sign
    STOCK_SIGN.fetch(kind, 0)
  end

  def holder_sign
    HOLDER_SIGN.fetch(kind, 0)
  end

  def recipient_required?
    RECIPIENT_KINDS.include?(kind)
  end

  def comment_required?
    WRITE_OFF_KINDS.include?(kind)
  end

  # Документ неизменяем: остаток двигается один раз при создании, и правка увела бы
  # его от факта. Ошибку прихода исправляют встречным списанием.
  def readonly?
    persisted?
  end

  private

  def lines
    uniform_operation_lines.reject(&:marked_for_destruction?)
  end

  def any_lines
    errors.add(:base, :no_lines) if lines.empty?
  end

  # Проверяем сумму по позиции, а не построчно: один документ может содержать
  # две строки на один и тот же размер, и порознь каждая пройдёт.
  def stock_available
    return unless stock_sign.negative?

    quantity_by_stock.each do |stock, requested|
      next if requested <= stock.quantity

      errors.add(:base, :exceeds_stock, size: stock.label, kind: stock.uniform_kind.name,
                                        available: stock.quantity)
    end
  end

  def holder_has_enough
    return unless holder_sign.negative? && recipient

    balance = UniformOperationLine.holder_balance(recipient)
    quantity_by_stock.each do |stock, requested|
      available = balance[stock.id].to_i
      next if requested <= available

      errors.add(:base, :exceeds_holder, size: stock.label, kind: stock.uniform_kind.name,
                                         holder: recipient.short_name, available: available)
    end
  end

  def quantity_by_stock
    lines.group_by(&:uniform_stock).each_with_object({}) do |(stock, stock_lines), totals|
      next if stock.nil?

      totals[stock] = stock_lines.sum { |line| line.quantity.to_i }
    end
  end
end
