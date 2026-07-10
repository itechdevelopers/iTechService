# frozen_string_literal: true

# Дизайн пакета — верхний уровень «таблички» пакетов. У каждого дизайна
# несколько строк-остатков (по размерам) и своя картинка, чтобы водитель
# понимал, за какой именно дизайн он берёт коробки.
class PackageDesign < ApplicationRecord
  has_many :package_stocks, -> { ordered }, inverse_of: :package_design, dependent: :destroy
  has_many :package_withdrawals, through: :package_stocks

  mount_uploader :image, PackageDesignUploader

  # Размеры редактируются прямо в форме дизайна. Признак «размер задан» —
  # заполненное «в коробке» (per_box_count): у реального размера штук в коробке
  # всегда > 0, а коробок может быть 0 (нет в наличии). Числовые поля формы
  # приходят как "0" от DB-дефолта, поэтому blank?-проверка бесполезна — нужен
  # именно to_i.zero?. Существующие строки удаляются через чекбокс (_destroy).
  accepts_nested_attributes_for :package_stocks, allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:id].blank? && attrs[:per_box_count].to_i.zero? }

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
