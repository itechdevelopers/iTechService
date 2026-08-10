# frozen_string_literal: true

class GisReviewFilter < BaseFilter
  # Месяц считаем по ДАТЕ ОТЗЫВА в 2ГИС, а не по created_at, как в BaseFilter:
  # агент может прислать июльский отзыв в августе (например, после починки
  # парсера), и в помесячной разбивке он должен остаться июльским.
  def filter_by_year_month
    return if filter[:year].blank?

    year = filter[:year].to_i
    month = filter[:month].to_i if filter[:month].present?
    start_date = Date.new(year, month || 1)
    end_date = Date.new(year, month || 12).at_end_of_month

    add_scope { |c| c.where(reviewed_at: start_date.beginning_of_day..end_date.end_of_day) }
  end
end
