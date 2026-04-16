# frozen_string_literal: true

class CheckListResponse < ApplicationRecord
  belongs_to :check_list
  belongs_to :checkable, polymorphic: true

  validates :check_list_id, uniqueness: { scope: [:checkable_type, :checkable_id] }
  validate :validate_required_questions

  serialize :responses, JSON

  # Virtual attribute for comments coming from nested attributes forms
  attr_accessor :comments

  before_validation :merge_flat_responses_and_comments

  # Storage format: { "item_id" => { "answer" => "yes", "comment" => "some text" } }
  # Form input format (flat): responses = { "item_id" => "yes" }, comments = { "item_id" => "text" }

  def answer_for_item(item_id)
    value = responses&.dig(item_id.to_s)
    return nil if value.blank?

    if value.is_a?(Hash)
      answer = value["answer"]
      return "yes" if answer == "true"
      answer
    else
      # Legacy flat format
      return "yes" if value == "true"
      value
    end
  end

  def comment_for_item(item_id)
    value = responses&.dig(item_id.to_s)
    return nil unless value.is_a?(Hash)
    value["comment"].presence
  end

  def set_answer(item_id, answer, comment: nil)
    self.responses ||= {}
    key = item_id.to_s

    if answer.present?
      entry = { "answer" => answer }
      entry["comment"] = comment if comment.present?
      self.responses[key] = entry
    else
      self.responses.delete(key)
    end
  end

  def answered?(item_id)
    answer_for_item(item_id).present?
  end

  private

  # Convert flat form input { "17" => "yes" } + comments { "17" => "text" }
  # into nested storage format { "17" => { "answer" => "yes", "comment" => "text" } }
  def merge_flat_responses_and_comments
    return if responses.blank?

    # Check if responses are in flat form format (values are strings, not hashes)
    first_value = responses.values.first
    if first_value.is_a?(String)
      merged = {}
      responses.each do |item_id, answer|
        next if answer.blank?
        entry = { "answer" => answer }
        comment = comments&.dig(item_id.to_s)
        entry["comment"] = comment if comment.present?
        merged[item_id.to_s] = entry
      end
      self.responses = merged
    elsif first_value.is_a?(Hash) && comments.present?
      # Already nested but comments came separately (shouldn't normally happen)
      comments.each do |item_id, comment|
        if responses[item_id.to_s].is_a?(Hash) && comment.present?
          responses[item_id.to_s]["comment"] = comment
        end
      end
    end

    self.comments = nil
  end

  def validate_required_questions
    return unless check_list.present?

    if check_list.has_main_question?
      main_question = check_list.main_question
      main_answer = answer_for_item(main_question.id)

      if main_question.required? && !answered?(main_question.id)
        errors.add(:base, I18n.t('check_lists.errors.required_question_not_answered',
                                 question: main_question.question))
      end

      # For yes/no: subordinate required only on "yes"
      # For custom answers: subordinate required on any answer
      subordinate_required = main_question.custom_answers? ? main_answer.present? : main_answer == "yes"
      if subordinate_required
        check_list.subordinate_items.where(required: true).each do |item|
          unless answered?(item.id)
            errors.add(:base, I18n.t('check_lists.errors.required_question_not_answered',
                                     question: item.question))
          end
        end
      end
    else
      check_list.check_list_items.where(required: true).each do |item|
        unless answered?(item.id)
          errors.add(:base, I18n.t('check_lists.errors.required_question_not_answered',
                                   question: item.question))
        end
      end
    end
  end
end
