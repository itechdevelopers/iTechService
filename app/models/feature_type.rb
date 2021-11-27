# frozen_string_literal: true

class FeatureType < ApplicationRecord
  KINDS = %w[imei serial_number].freeze

  default_scope { order('feature_types.kind asc') }
  scope :ordered, -> { order('feature_types.kind asc') }

  has_and_belongs_to_many :product_categories
  validates_presence_of :name, :kind
  validates_uniqueness_of :kind, unless: :is_other?
  validates_inclusion_of :kind, in: KINDS

  def is_imei?
    kind == 'imei'
  end

  def is_other?
    kind == 'other'
  end

  def self.kinds
    KINDS
  end

  def self.imei
    FeatureType.where(kind: 'imei').first
  end

  def self.serial_number
    FeatureType.where(kind: 'serial_number').first
  end
end
