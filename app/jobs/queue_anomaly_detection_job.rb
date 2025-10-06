class QueueAnomalyDetectionJob < ApplicationJob
  queue_as :reports

  def perform
    anomalies = []
    yesterday = Date.current - 1.day
    yesterday_range = yesterday.beginning_of_day..yesterday.end_of_day

    # Check all enabled electronic queues
    ElectronicQueue.enabled.includes(:department).find_each do |queue|
      # Type 1: Check for zero activity (no waiting clients created yesterday)
      zero_activity = check_zero_activity(queue, yesterday_range)
      anomalies << zero_activity if zero_activity

      # Type 2: Check for low activity (< 30% of 30-day average)
      low_activity = check_low_activity(queue, yesterday, yesterday_range)
      anomalies << low_activity if low_activity
    end

    # Send notification if any anomalies found
    if anomalies.any?
      QueueAnomalyMailer.anomaly_notification(anomalies).deliver_now
    end
  end

  private

  def check_zero_activity(queue, yesterday_range)
    # Check if any waiting clients were created yesterday for this queue
    has_activity = WaitingClient.joins(queue_item: :electronic_queue)
                              .where(electronic_queues: { id: queue.id })
                              .where(ticket_issued_at: yesterday_range)
                              .exists?

    unless has_activity
      {
        type: 'zero_activity',
        queue: queue,
        yesterday_count: 0,
        message: I18n.t('queue_anomaly.zero_activity',
                       queue_name: queue.queue_name,
                       department: queue.department.name)
      }
    end
  end

  def check_low_activity(queue, yesterday, yesterday_range)
    # Get yesterday's count for this specific queue
    yesterday_count = WaitingClient.joins(queue_item: :electronic_queue)
                                  .where(electronic_queues: { id: queue.id })
                                  .where(ticket_issued_at: yesterday_range)
                                  .count

    # Skip if zero activity (already caught by zero_activity check)
    return nil if yesterday_count == 0

    # Calculate 30-day average (excluding yesterday)
    thirty_days_ago = yesterday - 30.days
    period_range = thirty_days_ago.beginning_of_day..yesterday.beginning_of_day

    # Get average daily count over past 30 days
    daily_counts = WaitingClient.joins(queue_item: :electronic_queue)
                               .where(electronic_queues: { id: queue.id })
                               .where(ticket_issued_at: period_range)
                               .reorder(nil)
                               .group('DATE(ticket_issued_at)')
                               .count

    # Only check if we have sufficient historical data (at least 7 days)
    return nil if daily_counts.keys.count < 7

    average_daily_count = daily_counts.values.sum.to_f / daily_counts.keys.count
    threshold = average_daily_count * 0.3

    if yesterday_count < threshold && average_daily_count >= 1
      {
        type: 'low_activity',
        queue: queue,
        yesterday_count: yesterday_count,
        average_count: average_daily_count.round(1),
        threshold: threshold.round(1),
        message: I18n.t('queue_anomaly.low_activity',
                       queue_name: queue.queue_name,
                       department: queue.department.name,
                       yesterday_count: yesterday_count,
                       average_count: average_daily_count.round(1))
      }
    end
  end
end