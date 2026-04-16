# frozen_string_literal: true

class CheckListItem < ApplicationRecord
  DEFAULT_ANSWER_VARIANTS = %w[yes no].freeze

  scope :ordered, -> { order(:position) }
  scope :subordinate, ->(check_list) {
    check_list.has_main_question? ? where.not(id: check_list.main_question_id) : all
  }

  belongs_to :check_list

  validates :question, presence: true

  serialize :answer_variants, JSON

  acts_as_list scope: :check_list

  def answer_variants_raw=(value)
    self.answer_variants = if value.present?
      variants = value.split(',').map(&:strip).reject(&:blank?)
      variants.presence
    end
  end

  def is_main_question?
    check_list.main_question_id == id
  end

  def available_answers
    answer_variants.presence || DEFAULT_ANSWER_VARIANTS
  end

  def custom_answers?
    answer_variants.present? && answer_variants != DEFAULT_ANSWER_VARIANTS
  end
end
