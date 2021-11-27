# frozen_string_literal: true

class PriceType < ApplicationRecord
  KINDS = {
    0 => 'purchase',
    1 => 'retail',
    2 => 'other'
  }.freeze

  has_many :product_prices, inverse_of: :price_type
  has_many :revaluation_acts, inverse_of: :price_type
  has_and_belongs_to_many :stores
  validates_presence_of :name, :kind
  validates_inclusion_of :kind, in: KINDS.keys
  validates_uniqueness_of :kind

  def kind_s
    KINDS[kind]
  end

  def self.purchase
    create_with(name: I18n.t('price_types.kinds.purchase')).find_or_create_by(kind: 0)
  end

  def self.retail
    create_with(name: I18n.t('price_types.kinds.retail')).find_or_create_by(kind: 1)
  end

  def is_purchase?
    kind.zero?
  end

  def is_retail?
    kind == 1
  end
end
