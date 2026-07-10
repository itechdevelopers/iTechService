# frozen_string_literal: true

# Строка остатка = пара «дизайн + размер». boxes_count — отслеживаемая величина
# (её списывают заборы и по ней срабатывает порог). «Всего штук» не храним —
# считаем на лету, чтобы нечего было «сломать» (боль исходной гугл-таблицы).
class PackageStock < ApplicationRecord
  belongs_to :package_design, inverse_of: :package_stocks
  has_many :package_withdrawals, dependent: :destroy

  # size — свободный текст (вводит суперадмин), не enum. Уникален в рамках дизайна.
  validates :size, presence: true
  validates :size, uniqueness: { scope: :package_design_id }
  validates :boxes_count, :per_box_count,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :low_stock_threshold,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  # Порядок ввода админом (свободный текст размера не отсортируешь осмысленно).
  scope :ordered, -> { order(:id) }

  # Всего штук = коробки × штук в коробке (производная, не колонка).
  def total_count
    boxes_count.to_i * per_box_count.to_i
  end

  # На пороге дозаказа? Порог задан и коробок не больше него.
  def low_stock?
    low_stock_threshold.present? && boxes_count.to_i <= low_stock_threshold
  end

  # Подпись пункта в выпадашке водителя: «Средний — в наличии 7 кор.».
  def select_label
    I18n.t('package_stocks.select_label', size: size, boxes: boxes_count)
  end
end
