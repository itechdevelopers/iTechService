class BootstrapTodayFinalizationsJob < ApplicationJob
  queue_as :default

  def perform
    City.find_each do |city|
      tz = city.time_zone.presence || 'Vladivostok'

      Time.use_zone(tz) do
        today = Time.zone.today

        entries = ScheduleEntry
                  .joins(:occupation_type, :schedule_group)
                  .where(date: today)
                  .where(schedule_groups: { city_id: city.id })
                  .where(occupation_types: { counts_as_working: true })

        entries.find_each do |entry|
          end_seconds = entry.effective_end_seconds
          next unless end_seconds

          finalize_at = Time.zone.local(entry.date.year, entry.date.month, entry.date.day) +
                        end_seconds.seconds + 10.minutes

          # Cron may run after a user's shift already ended (e.g. an early-morning shift
          # finished before 08:00). Skip — nothing to finalize at a past moment.
          next if finalize_at.past?

          FinalizeUserShiftJob.set(wait_until: finalize_at).perform_later(entry.user_id)
        end
      end
    end
  end
end
