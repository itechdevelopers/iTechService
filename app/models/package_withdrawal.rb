# frozen_string_literal: true

# Факт забора пакетов водителем — заменяет «колонки-даты» из гугл-таблицы.
# Списание остатка и проверка порога появятся в Цикле 3 (after_commit).
class PackageWithdrawal < ApplicationRecord
  belongs_to :package_stock
  belongs_to :user

  has_one :package_design, through: :package_stock

  validates :boxes_count,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :withdrawn_on, presence: true
  validates :reason, presence: true
  validate :within_available, on: :create

  scope :recent, -> { order(withdrawn_on: :desc, created_at: :desc) }

  # Списываем коробки в той же транзакции, что и вставка забора. after_commit
  # (не after_save) для уведомления — колбэк видит уже закоммиченный остаток,
  # см. memory feedback_after_commit_in_operations.
  after_create :decrement_stock
  after_commit :notify_if_low_stock, on: :create

  private

  def within_available
    return if package_stock.blank? || boxes_count.blank?

    available = package_stock.boxes_count
    errors.add(:boxes_count, :exceeds_available, count: available) if boxes_count > available
  end

  def decrement_stock
    package_stock.decrement!(:boxes_count, boxes_count)
  end

  def notify_if_low_stock
    package_stock.reload
    PackageLowStockNotifier.call(package_stock) if package_stock.low_stock?
  end
end
