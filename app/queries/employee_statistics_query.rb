# frozen_string_literal: true

# Aggregates per-user counters for one of the User::ACTIVITIES metrics
# across all users in a given city for a given month. Result is sorted
# worst → best (ascending by count) so the leaderboard nudges
# under-performers at the top.
class EmployeeStatisticsQuery
  # Бит маски по-прежнему считается по полному списку ACTIVITIES.
  ALLOWED_METRICS = User::STATISTICS_ACTIVITIES

  def initialize(metric:, month:, city_id:, department_id: nil, from_date: nil, to_date: nil)
    raise ArgumentError, "metric #{metric.inspect} not in #{ALLOWED_METRICS}" unless ALLOWED_METRICS.include?(metric.to_s)

    @metric   = metric.to_s
    @month    = month.to_date.beginning_of_month
    @city_id  = city_id
    @department_id = department_id
    @from_date = from_date&.to_date || @month
    @to_date = to_date&.to_date || @month.end_of_month
    raise ArgumentError, 'Invalid date range' if @from_date > @to_date
  end

  def call
    if metric == 'reviews'
      counts = review_counts
      # Include actual review owners even if their activity checkbox is off or
      # they have since moved: attribution follows the review's branch.
      users = User.active.where(id: eligible_users.pluck(:id) + counts.keys).order(:name).to_a
    else
      users = eligible_users.to_a
      counts = fetch_counts(users.map(&:id))
    end
    users.map { |u| [u, counts.fetch(u.id, 0)] }.sort_by { |_, count| count }
  end

  private

  attr_reader :metric, :month, :city_id, :department_id, :from_date, :to_date

  def eligible_users
    scope = User.active
        .joins(:department)
        .where(departments: { city_id: city_id })
        .where('users.activities_mask & ? > 0', activity_bit)
        .order(:name)
    department_id ? scope.where(department_id: department_id) : scope
  end

  def activity_bit
    2**User::ACTIVITIES.index(metric)
  end

  def month_range
    month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
  end

  def fetch_counts(user_ids)
    return {} if user_ids.empty?

    case metric
    when 'free' then free_counts(user_ids)
    when 'fast' then fast_counts(user_ids)
    when 'long' then long_counts(user_ids)
    when 'mac'  then mac_counts(user_ids)
    end
  end

  def review_counts
    zone = City.find(city_id).time_zone.presence || Time.zone
    range = Time.use_zone(zone) { from_date.beginning_of_day...to_date.next_day.beginning_of_day }
    scope = GisReview.assigned.where(source: %w[2gis yandex], city_id: city_id, reviewed_at: range)
                     .where.not(user_id: nil)
    scope = scope.where(department_id: department_id) if department_id
    scope.group(:user_id).count
  end

  def free_counts(user_ids)
    Service::FreeJob.where(receiver_id: user_ids, performed_at: month_range)
                    .group(:receiver_id).count
  end

  def fast_counts(user_ids)
    QuickOrder.where(user_id: user_ids, created_at: month_range)
              .group(:user_id).count
  end

  def long_counts(user_ids)
    ServiceJob.where(user_id: user_ids, created_at: month_range)
              .group(:user_id).count
  end

  def mac_counts(user_ids)
    DeviceTask.joins(:task)
              .where(performer_id: user_ids, done_at: month_range, tasks: { code: 'mac' })
              .group(:performer_id).count
  end
end
