# frozen_string_literal: true

# Вид рабочей формы — верхний уровень учёта. У вида есть картинка, описание,
# себестоимость и набор размеров; каждый размер материализуется строкой остатка
# (uniform_stocks), по которой дальше идут приход, списание и выдача.
class UniformKind < ApplicationRecord
  SIZES = %w[xs s m l xl 2xl 3xl 4xl].freeze

  has_many :uniform_stocks, -> { ordered }, inverse_of: :uniform_kind, dependent: :destroy

  mount_uploader :image, UniformKindUploader

  validates :name, presence: true
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :used_sizes_kept

  scope :ordered, -> { order(:name) }

  # Вид с историей движений не удаляем: журнал должен пережить правку справочника.
  # Из оборота такой вид выводят, обнулив остатки списанием.
  # prepend обязателен: dependent: :destroy у uniform_stocks вешает свой before_destroy
  # в момент объявления связи, то есть раньше этой проверки, и без prepend строки
  # остатков успели бы уйти под внешний ключ строк документов.
  before_destroy :ensure_no_movements, prepend: true

  def movements
    UniformOperationLine.for_stocks(uniform_stocks.select(:id))
  end

  # Размеры формы задаются галочками, поэтому снаружи вид выглядит как объект с
  # массивом размеров, а внутри это строки остатков. Пока форма не прислала список,
  # отдаём то, что уже есть в базе.
  def sizes
    @sizes || uniform_stocks.map(&:size)
  end

  def sizes=(values)
    @sizes = Array(values).map(&:to_s).select { |size| SIZES.include?(size) }.uniq
  end

  def total_quantity
    uniform_stocks.sum(&:quantity)
  end

  def quantity_for(size)
    uniform_stocks.detect { |stock| stock.size == size }&.quantity
  end

  after_save :sync_stocks

  private

  # Снятая галочка удаляет строку остатка, поэтому снимать её можно только с тех
  # размеров, по которым нечего потерять. Запросом, а не перебором коллекции:
  # загруженная ассоциация может держать остаток, каким он был до прихода.
  def used_sizes_kept
    return if @sizes.nil?

    lost = unchecked_stocks.reject(&:removable?)
    return if lost.empty?

    errors.add(:sizes, :in_use, sizes: lost.map(&:label).join(', '))
  end

  def sync_stocks
    return if @sizes.nil?

    unchecked_stocks.each { |stock| stock.destroy if stock.removable? }
    (@sizes - uniform_stocks.reload.map(&:size)).each { |size| uniform_stocks.create!(size: size) }
    @sizes = nil
  end

  # Размеры, с которых галочка снята. where.not(size: []) даёт все строки — ровно
  # то, что нужно, когда сняли вообще все галочки.
  def unchecked_stocks
    uniform_stocks.where.not(size: @sizes).to_a
  end

  def ensure_no_movements
    return if movements.none?

    errors.add(:base, :has_movements)
    throw(:abort)
  end
end
