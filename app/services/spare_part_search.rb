# frozen_string_literal: true

# Поиск запчастей по названию для ревизии: и при выборе номенклатуры, и при
# добавлении забытой позиции в уже собранный список.
#
#   SparePartSearch.call('дисплей') # => ActiveRecord::Relation of Product
class SparePartSearch
  LIMIT = 30

  def self.call(query)
    new(query).call
  end

  def initialize(query)
    @query = query.to_s.strip
  end

  def call
    return Product.none if query.blank?

    Product.joins(:product_category)
           .where(product_categories: { kind: 'spare_part' })
           .where(name_condition, q: term)
           .limit(LIMIT)
  end

  private

  attr_reader :query

  # Регистронезависимость через явную коллацию, а не LOWER(): база создана с
  # коллацией C, где lower() кириллицу не трогает и «дисплей» никогда не найдёт
  # «Дисплей». Имя коллации спрашиваем у базы — на проде и локально оно
  # пишется по-разному.
  def name_condition
    collation ? %(products.name ILIKE :q COLLATE "#{collation}") : 'LOWER(products.name) LIKE :q'
  end

  def term
    collation ? "%#{query}%" : "%#{query.mb_chars.downcase}%"
  end

  def collation
    return @collation if defined?(@collation)

    @collation = Item.russian_collation
  end
end
