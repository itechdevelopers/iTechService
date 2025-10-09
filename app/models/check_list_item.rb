# frozen_string_literal: true

class CheckListItem < ApplicationRecord
  scope :ordered, -> { order(:position) }
  scope :subordinate, ->(check_list) {
    check_list.has_main_question? ? where.not(id: check_list.main_question_id) : all
  }

  belongs_to :check_list

  validates :question, presence: true

  acts_as_list scope: :check_list

  def is_main_question?
    check_list.main_question_id == id
  end
end
