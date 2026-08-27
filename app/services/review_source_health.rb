# frozen_string_literal: true

# Состояние сбора отзывов: матрица «филиал × площадка» плюс список открытых
# аварий и история закрытых.
#
# Агент сообщает только об АВАРИЯХ, поэтому «работает» — это вывод, а не факт:
# он означает «открытой аварии нет». Порог у агента 24 часа, значит зелёная
# ячейка читается как «за последние сутки не было непрерывного отказа». Чтобы
# вывод не был голым, рядом показываем дату последнего отзыва по этой паре —
# единственный фактический признак, что сбор по ней вообще идёт.
class ReviewSourceHealth
  # Ячейка матрицы: одна пара «филиал × площадка».
  Cell = Struct.new(:source, :alert, :last_review_at, keyword_init: true) do
    def state
      return :failing if alert.present?
      return :unknown if last_review_at.blank?

      :working
    end

    def failing?
      state == :failing
    end
  end

  Row = Struct.new(:branch_code, :department, :branch_name, :cells, keyword_init: true) do
    def label
      department&.name.presence || branch_name.presence || branch_code
    end

    def city_name
      department&.city&.name
    end
  end

  RESOLVED_HISTORY_LIMIT = 15

  def initialize(sources: ReviewSourceAlert::SOURCES)
    @sources = sources
  end

  def open_alerts
    @open_alerts ||= ReviewSourceAlert.unresolved.includes(:department).sort_by do |alert|
      # Самые долгие сверху: разбирать начинают с них.
      [-(alert.duration_hours || 0)]
    end
  end

  def resolved_alerts
    @resolved_alerts ||= ReviewSourceAlert.resolved.includes(:department)
                                          .order(resolved_at: :desc)
                                          .limit(RESOLVED_HISTORY_LIMIT)
  end

  def rows
    @rows ||= branch_codes.map { |code| build_row(code) }
                          .sort_by { |row| [row.city_name.to_s, row.label.to_s] }
  end

  def sources
    @sources
  end

  # Аварии площадки целиком красят весь столбец: филиальной записи по ним нет,
  # но сбор не идёт ни по одному филиалу.
  def global_alert(source)
    global_alerts[source]
  end

  private

  def global_alerts
    @global_alerts ||= open_alerts.select(&:global?).index_by(&:source)
  end

  def branch_alerts
    @branch_alerts ||= open_alerts.reject(&:global?).index_by { |a| [a.source, a.branch_code] }
  end

  # Дата последнего отзыва по паре «площадка + филиал» — одним запросом на всю
  # таблицу вместо запроса на ячейку.
  def last_reviews
    @last_reviews ||= GisReview.group(:source, :branch_code).maximum(:reviewed_at)
  end

  # Филиалы, о которых нам вообще есть что сказать: те, откуда приходили отзывы,
  # плюс те, по которым заводились аварии. Полный справочник подразделений тут
  # не годится — половина из них к отзывам отношения не имеет.
  def branch_codes
    @branch_codes ||= begin
      from_reviews = last_reviews.keys.map(&:last)
      from_alerts = ReviewSourceAlert.distinct.pluck(:branch_code)
      (from_reviews + from_alerts).map(&:presence).compact.uniq
    end
  end

  def departments
    @departments ||= Department.includes(:city).where(code: branch_codes).index_by(&:code)
  end

  # Название филиала на случай, когда код не резолвится в подразделение:
  # берём последнее, что присылал агент.
  def branch_names
    @branch_names ||= ReviewSourceAlert.where.not(branch_name: nil)
                                       .pluck(:branch_code, :branch_name).to_h
                                       .merge(GisReview.where.not(branch_name: nil)
                                                       .pluck(:branch_code, :branch_name).to_h)
  end

  def build_row(code)
    Row.new(
      branch_code: code,
      department: departments[code],
      branch_name: branch_names[code],
      cells: @sources.map do |source|
        Cell.new(
          source: source,
          alert: branch_alerts[[source, code]] || global_alerts[source],
          last_review_at: last_reviews[[source, code]]
        )
      end
    )
  end
end
