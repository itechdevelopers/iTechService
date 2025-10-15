module Checkable
  extend ActiveSupport::Concern

  included do
    has_many :check_list_responses,
              as: :checkable,
              dependent: :destroy,
              inverse_of: :checkable

    accepts_nested_attributes_for :check_list_responses,
                                  allow_destroy: true,
                                  reject_if: proc { |attrs| attrs[:check_list_id].blank? }

    validates_associated :check_list_responses
  end

  def available_check_lists
    CheckList.active.for_entity(self.class.name)
  end

  def check_list_response_for(check_list)
    check_list_responses.find_by(check_list: check_list)
  end

  def check_lists_complete?
    # Check if all required questions across all active check lists are answered
    available_check_lists.all? do |check_list|
      response = check_list_response_for(check_list)
      next true unless response # No response is OK if checklist is not being filled

      response.valid?
    end
  end

  def unanswered_required_questions
    # Helper method to get all unanswered required questions
    questions = []

    check_list_responses.each do |response|
      check_list = response.check_list
      next unless check_list

      # Get questions that need to be checked based on main question status
      questions_to_check = if check_list.has_main_question?
                            main_answer = response.answer_for_item(check_list.main_question_id)
                            if main_answer == "yes" || main_answer == "true"
                              check_list.check_list_items.where(required: true)
                            else
                              check_list.check_list_items.where(id: check_list.main_question_id, required: true)
                            end
                          else
                            check_list.check_list_items.where(required: true)
                          end

      questions_to_check.each do |item|
        unless response.answered?(item.id)
          questions << "#{check_list.name}: #{item.question}"
        end
      end
    end

    questions
  end
end
