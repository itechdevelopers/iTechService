# frozen_string_literal: true

# Дизайн пакета — верхний уровень «таблички» пакетов. У каждого дизайна
# несколько строк-остатков (по размерам) и своя картинка, чтобы водитель
# понимал, за какой именно дизайн он берёт коробки.
class PackageDesign < ApplicationRecord
  has_many :package_stocks, dependent: :destroy
  has_many :package_withdrawals, through: :package_stocks

  mount_uploader :image, PackageDesignUploader

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
