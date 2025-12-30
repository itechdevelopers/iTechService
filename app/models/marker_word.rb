# frozen_string_literal: true

class MarkerWord < ApplicationRecord
  validates :word, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_word

  private

  def normalize_word
    self.word = word.strip.mb_chars.downcase.to_s if word.present?
  end
end
