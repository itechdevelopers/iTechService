# frozen_string_literal: true

# Дизайн пакета — верхний уровень «таблички» пакетов. У каждого дизайна
# несколько строк-остатков (по размерам) и своя картинка, чтобы водитель
# понимал, за какой именно дизайн он берёт коробки.
class PackageDesign < ApplicationRecord
  has_many :package_stocks, -> { ordered }, inverse_of: :package_design, dependent: :destroy
  has_many :package_withdrawals, through: :package_stocks

  mount_uploader :image, PackageDesignUploader

  # Размеры редактируются прямо в форме дизайна. reject_if пропускает новые
  # (без id) строки, где не заполнили коробки, — так «недобавленный» размер
  # не создаётся. Существующие строки удаляются через чекбокс (_destroy).
  accepts_nested_attributes_for :package_stocks, allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:id].blank? && attrs[:boxes_count].blank? }

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
