# frozen_string_literal: true

class CheckListResponse < ApplicationRecord
  belongs_to :check_list
  belongs_to :checkable, polymorphic: true

  validates :check_list_id, uniqueness: { scope: [:checkable_type, :checkable_id] }

  serialize :responses, JSON

  def answer_for_item(item_id)
    responses&.dig(item_id.to_s)
  end

  def set_answer(item_id, value)
    self.responses ||= {}
    self.responses[item_id.to_s] = value
  end
end
