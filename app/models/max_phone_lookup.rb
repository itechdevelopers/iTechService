# frozen_string_literal: true

# Запомненный ответ MAX на вопрос «есть ли аккаунт на этом номере» — см.
# MaxPhoneAccountSearch.
class MaxPhoneLookup < ApplicationRecord
  # Найденный аккаунт со временем может смениться — номер передали другому
  # человеку, — поэтому и положительный ответ живёт не вечно. Отрицательный
  # короче: клиент мог за это время завести MAX.
  FOUND_TTL = 30.days
  NOT_FOUND_TTL = 7.days

  validates :phone, :checked_at, presence: true
  validates :phone, uniqueness: true

  def fresh?
    checked_at > (found? ? FOUND_TTL : NOT_FOUND_TTL).ago
  end
end
