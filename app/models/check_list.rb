# frozen_string_literal: true

class CheckList < ApplicationRecord
  ENTITY_TYPES = %w[TradeInDevice Product Task ServiceJob].freeze

  has_many :check_list_items, dependent: :destroy
  has_many :check_list_responses, dependent: :destroy

  validates :name, presence: true
  validates :entity_type, presence: true, inclusion: { in: ENTITY_TYPES }

  scope :active, -> { where(active: true) }
  scope :for_entity, ->(entity_type) { where(entity_type: entity_type) }

  accepts_nested_attributes_for :check_list_items,
                                allow_destroy: true,
                                reject_if: :all_blank

  paginates_per 20

  def entity_class
    entity_type.constantize
  end
end
