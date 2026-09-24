class RefreshRepairCountsJob < ApplicationJob
  queue_as :reports

  def perform(full: false)
    # Reconcile the historical window monthly; ordinary daily runs update YTD.
    today = Time.current.in_time_zone('Asia/Vladivostok').to_date
    ActivityCounts::RefreshRepairs.call(full: full || today.day == 1, today: today)
  end
end
