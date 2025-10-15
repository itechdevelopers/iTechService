# frozen_string_literal: true

class CheckListResponse < ApplicationRecord
  belongs_to :check_list
  belongs_to :checkable, polymorphic: true

  validates :check_list_id, uniqueness: { scope: [:checkable_type, :checkable_id] }
  validate :validate_required_questions

  serialize :responses, JSON

  def answer_for_item(item_id)
    # Returns the actual answer: "yes", "no", or nil for unanswered
    value = responses&.dig(item_id.to_s)

    # Handle legacy data: convert "true" to "yes" for backward compatibility
    return "yes" if value == "true"
    return nil if value.blank?

    value
  end

  def set_answer(item_id, value)
    self.responses ||= {}
    # Only set if value is "yes" or "no", remove if blank
    if value.present? && ["yes", "no"].include?(value)
      self.responses[item_id.to_s] = value
    elsif value.blank?
      self.responses.delete(item_id.to_s)
    end
  end

  def answered?(item_id)
    ["yes", "no", "true"].include?(responses&.dig(item_id.to_s))
  end

  private

  def validate_required_questions
    return unless check_list.present?

    if check_list.has_main_question?
      main_question = check_list.main_question
      main_answer = answer_for_item(main_question.id)

      # First: Validate main question if it's required
      if main_question.required? && !answered?(main_question.id)
        errors.add(:base, I18n.t('check_lists.errors.required_question_not_answered',
                                 question: main_question.question))
      end

      # Second: Only validate subordinate questions if main question answered "yes"
      if main_answer == "yes" || main_answer == "true"
        check_list.subordinate_items.where(required: true).each do |item|
          unless answered?(item.id)
            errors.add(:base, I18n.t('check_lists.errors.required_question_not_answered',
                                     question: item.question))
          end
        end
      end
    else
      # No main question - validate all required questions
      check_list.check_list_items.where(required: true).each do |item|
        unless answered?(item.id)
          errors.add(:base, I18n.t('check_lists.errors.required_question_not_answered',
                                   question: item.question))
        end
      end
    end
  end
end
