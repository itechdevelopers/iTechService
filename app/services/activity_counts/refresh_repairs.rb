require 'digest'

module ActivityCounts
  class RefreshRepairs
    # Only this background service scans history. Requests use stored daily counts.
    def self.call(full: false, today: Time.current.in_time_zone('Asia/Vladivostok').to_date)
      new.call(full: full, today: today)
    end

    def call(full:, today:)
      connection = ActiveRecord::Base.connection
      locked = connection.select_value('SELECT pg_try_advisory_lock(734243)')
      return unless locked == true || locked == 't'
      begin
        first = Date.new(today.year - ((full || !ActivityCountDay.where(metric: 'issued_repairs').exists?) ? 6 : 0), 1, 1)
        last = today - 1
        return if last < first
        stamp = Time.current
        # First archive entry for each job, across its entire history. Filtering
        # dates BEFORE DISTINCT ON would count repeat issuances in a later year.
        rows = connection.select_all(<<~SQL).to_a
          WITH issued AS (
            SELECT DISTINCT ON (h.object_id) h.object_id, h.created_at, archive.department_id
            FROM history_records h
            JOIN locations archive ON h.new_value = archive.id::text AND archive.code = 'archive'
            WHERE h.object_type = 'ServiceJob' AND h.column_name = 'location_id'
              AND h.object_id IS NOT NULL AND h.deleted_at IS NULL AND h.old_value IS NOT NULL AND h.old_value <> ''
              AND NOT EXISTS (SELECT 1 FROM locations old WHERE old.code = 'archive' AND old.id::text = h.old_value)
            ORDER BY h.object_id, h.created_at, h.id
          ), dated AS (
            SELECT (created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Vladivostok')::date AS day, department_id
            FROM issued
          )
          SELECT day, department_id, count(*) AS quantity
          FROM dated WHERE day >= #{connection.quote(first)} AND day <= #{connection.quote(last)}
          GROUP BY day, department_id ORDER BY day, department_id
        SQL
        names = Department.pluck(:id, :name).to_h
        grouped = rows.group_by { |row| row['day'].to_s }
        (first..last).group_by { |day| [day.year, day.month] }.each_value do |dates|
          days = dates.map do |day|
            branches = (grouped[day.iso8601] || []).map do |row|
              id = row['department_id']&.to_i
              {id: id ? id.to_s : 'unknown', name: names[id] || 'Неизвестный магазин', quantity: row['quantity'].to_i}
            end
            {date: day.iso8601, quantity: branches.sum { |branch| branch[:quantity] }, branches: branches}
          end
          report = {schema_version: 'activity-counts-1.0', metric: 'issued_repairs', methodology_version: 'first-archive-issue-1.0',
            period: {from: dates.first.iso8601, to: dates.last.iso8601}, calculated_at: stamp.iso8601(6),
            source: {name: 'AIS history_records', read_only: true}, checks: {all_pages_received: true, duplicates: 0},
            quantity: days.sum { |day| day[:quantity] }, days: days}
          json = JSON.generate(report)
          Import.call(delivery_id: Digest::SHA256.hexdigest(json), report: JSON.parse(json), allowed_metric: 'issued_repairs')
        end
      ensure
        connection.execute('SELECT pg_advisory_unlock(734243)')
      end
    end
  end
end
