# frozen_string_literal: true

class SeedManageNegativeReviewsAbility < ActiveRecord::Migration[5.1]
  # Право «Работа с негативными отзывами 2ГИС». Страницу негативных отзывов и
  # смену их статусов видят суперадмины ИЛИ обладатели этого права. Переброс
  # отзыва другому сотруднику остаётся только за суперадмином (policy #reassign?).
  # admin_assignable оставляем false — выдаёт право суперадмин.
  def up
    Ability.find_or_create_by!(name: 'manage_negative_reviews') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'manage_negative_reviews')&.destroy
  end
end
