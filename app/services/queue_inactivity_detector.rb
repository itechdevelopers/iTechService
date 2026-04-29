class QueueInactivityDetector
  DEFAULT_TIME_ZONE = 'Vladivostok'.freeze

  attr_reader :waiting_client

  def initialize(waiting_client)
    @waiting_client = waiting_client
  end

  def threshold_exceeded?
    return false unless waiting_client.status == 'waiting'
    return false if alert_setting.nil?
    return false if schedule_group.nil?
    return false if min_unattended_seconds.blank? || min_unattended_seconds <= 0
    return false if waited_seconds < min_unattended_seconds
    return false if max_inactive_for_current_shift.nil?

    inactive_users_count > max_inactive_for_current_shift
  end

  def total_on_shift
    return 0 if schedule_group.nil?

    @total_on_shift ||= working_now_group_user_ids.size
  end

  def active_users_count
    active_users.size
  end

  def inactive_users_count
    total_on_shift - active_users_count
  end

  def waited_seconds
    return 0 if waiting_client.ticket_issued_at.blank?

    (Time.zone.now - waiting_client.ticket_issued_at).to_i
  end

  def max_inactive_for_current_shift
    return nil if total_on_shift <= 0

    @max_inactive_for_current_shift ||= electronic_queue.inactivity_thresholds
                                                       .find_by(total_on_shift: total_on_shift)
                                                       &.max_inactive
  end

  def metadata
    {
      total_on_shift: total_on_shift,
      active_users_count: active_users_count,
      inactive_users_count: inactive_users_count,
      max_inactive_allowed: max_inactive_for_current_shift,
      waited_seconds: waited_seconds,
      min_unattended_seconds: min_unattended_seconds,
      now_in_city: now_in_city.iso8601,
      schedule_group_id: schedule_group&.id,
      threshold_exceeded: threshold_exceeded?
    }
  end

  private

  def electronic_queue
    @electronic_queue ||= waiting_client.electronic_queue
  end

  def alert_setting
    @alert_setting ||= electronic_queue.inactivity_alert_setting
  end

  def schedule_group
    @schedule_group ||= alert_setting&.schedule_group
  end

  def min_unattended_seconds
    alert_setting&.min_unattended_seconds
  end

  def now_in_city
    @now_in_city ||= Time.current.in_time_zone(city_time_zone)
  end

  def city_time_zone
    electronic_queue.department.city&.time_zone || DEFAULT_TIME_ZONE
  end

  def active_member_ids
    @active_member_ids ||= schedule_group.active_members.pluck(:id)
  end

  def working_now_group_user_ids
    @working_now_group_user_ids ||= begin
      today = now_in_city.to_date
      seconds = now_in_city.seconds_since_midnight

      ScheduleEntry
        .where(schedule_group: schedule_group, user_id: active_member_ids, date: today)
        .joins(:occupation_type).where(occupation_types: { counts_as_working: true })
        .includes(:shift)
        .select { |e| e.covers_time?(seconds) }
        .map(&:user_id)
        .uniq
    end
  end

  def active_users
    @active_users ||= active_user_ids - paused_user_ids
  end

  def active_user_ids
    @active_user_ids ||= ElqueueWindow.active
                                      .where(electronic_queue_id: electronic_queue.id)
                                      .joins(:user)
                                      .pluck('users.id')
  end

  def paused_user_ids
    @paused_user_ids ||= UserPause.where(resumed_at: nil).pluck(:user_id)
  end
end
