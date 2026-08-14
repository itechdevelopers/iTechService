# frozen_string_literal: true

# Сводка по отзывам за месяц: всего, по городам с разбивкой по подразделениям
# и по площадкам. Используется и компактной строкой над таблицей привязки,
# и полноценной страницей статистики.
#
#   GisReviewStatsQuery.new(month: Date.current).call
class GisReviewStatsQuery
  CityRow = Struct.new(:city_name, :count, :departments, keyword_init: true)
  DepartmentRow = Struct.new(:name, :count, keyword_init: true)

  def initialize(month:, source: nil)
    @month = month.to_date
    @source = source.presence
  end

  def call
    {
      total: scope.count,
      by_city: by_city,
      by_source: by_source
    }
  end

  private

  attr_reader :month, :source

  def scope
    relation = GisReview.in_month(month)
    relation = relation.where(source: source) if source
    relation
  end

  # Группируем по городу И подразделению одним запросом: городов и филиалов
  # единицы, но отзывов могут быть тысячи — по запросу на филиал не годится.
  # city_name, а не связь city: у отзыва с нераспознанным городом связи нет,
  # а строка есть всегда, и терять такие отзывы из сводки нельзя.
  def by_city
    counts = scope.group(:city_name, :department_id).count
    departments = Department.where(id: counts.keys.map(&:last).compact.uniq).index_by(&:id)

    counts.each_with_object({}) do |((city_name, department_id), count), acc|
      row = acc[city_name] ||= CityRow.new(city_name: city_name, count: 0, departments: [])
      row.count += count
      row.departments << DepartmentRow.new(
        name: departments[department_id]&.name || I18n.t('gis_reviews.statistics.unknown_department'),
        count: count
      )
    end.values.sort_by { |row| -row.count }.each { |row| row.departments.sort_by! { |d| -d.count } }
  end

  def by_source
    scope.group(:source).count.sort_by { |_, count| -count }
  end
end
