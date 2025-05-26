# frozen_string_literal: true

class CheckListItem < ApplicationRecord
  scope :ordered, -> { order(:position) }

  belongs_to :check_list

  validates :question, presence: true
  validates :position, presence: true, uniqueness: { scope: :check_list_id }

  before_validation :set_position, on: :create

  private

  def set_position
    return if position.present?

    max_position = check_list&.check_list_items&.maximum(:position) || 0
    self.position = max_position + 1
  end
end
