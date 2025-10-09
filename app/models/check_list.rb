# frozen_string_literal: true

class CheckList < ApplicationRecord
  ENTITY_TYPES = %w[TradeInDevice Product Task ServiceJob RepairTask DeviceTask].freeze

  has_many :check_list_items, dependent: :destroy
  has_many :check_list_responses, dependent: :destroy
  belongs_to :main_question, class_name: 'CheckListItem', optional: true

  validates :name, presence: true
  validates :entity_type, presence: true, inclusion: { in: ENTITY_TYPES }
  validate :main_question_belongs_to_this_checklist

  scope :active, -> { where(active: true) }
  scope :for_entity, ->(entity_type) { where(entity_type: entity_type) }

  accepts_nested_attributes_for :check_list_items,
                                allow_destroy: true,
                                reject_if: :all_blank

  paginates_per 20

  def entity_class
    entity_type.constantize
  end

  def has_main_question?
    main_question_id.present?
  end

  def subordinate_items
    return check_list_items.ordered unless has_main_question?
    check_list_items.where.not(id: main_question_id).ordered
  end

  private

  def main_question_belongs_to_this_checklist
    return unless main_question_id.present?

    unless check_list_items.exists?(id: main_question_id)
      errors.add(:main_question, 'must belong to this checklist')
    end
  end
end
