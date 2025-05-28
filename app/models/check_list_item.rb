# frozen_string_literal: true

class CheckListItem < ApplicationRecord
  scope :ordered, -> { order(:position) }

  belongs_to :check_list

  validates :question, presence: true

  acts_as_list scope: :check_list
end
