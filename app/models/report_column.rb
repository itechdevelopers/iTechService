# frozen_string_literal: true

class ReportColumn < ApplicationRecord
  belongs_to :reports_board
  has_many :report_cards

  validates :name, presence: true

  def last_card_position
    report_cards.maximum(:position) || 0
  end
end
