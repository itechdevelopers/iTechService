# frozen_string_literal: true

# Aggregates per-user counters for one of the User::ACTIVITIES metrics
# across all users in a given city for a given month. Result is sorted
# worst → best (ascending by count) so the leaderboard nudges
# under-performers at the top.
class EmployeeStatisticsQuery
  ALLOWED_METRICS = User::ACTIVITIES

  def initialize(metric:, month:, city_id:)
    raise ArgumentError, "metric #{metric.inspect} not in #{ALLOWED_METRICS}" unless ALLOWED_METRICS.include?(metric.to_s)

    @metric   = metric.to_s
    @month    = month.to_date.beginning_of_month
    @city_id  = city_id
  end

  def call
    users  = eligible_users.to_a
    counts = fetch_counts(users.map(&:id))
    users.map { |u| [u, counts.fetch(u.id, 0)] }.sort_by { |_, count| count }
  end

  private

  attr_reader :metric, :month, :city_id

  def eligible_users
    User.active
        .joins(:department)
        .where(departments: { city_id: city_id })
        .where('users.activities_mask & ? > 0', activity_bit)
        .order(:name)
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
