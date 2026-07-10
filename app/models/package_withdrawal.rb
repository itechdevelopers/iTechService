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

  scope :recent, -> { order(withdrawn_on: :desc, created_at: :desc) }
end
