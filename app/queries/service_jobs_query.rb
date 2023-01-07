# frozen_string_literal: true

class ServiceJobsQuery
  def initialize(scope = ServiceJob.all)
    @sope = scope
  end

  def stale_at_done_over(term, department_id: nil)
    done_locations = Location.done
    done_locations = done_locations.in_department(department_id) unless department_id.nil?
    storage_locations = done_locations.where(storage_term: term)
    min_term = Location.done.minimum(:storage_term)
    done_location_ids = Location.done.where(storage_term: min_term).pluck(:id)

    @sope.includes(:history_records)
         .where('history_records.created_at < ?', term.months.ago)
         .where(location: storage_locations,
                history_records: {column_name: 'location_id', new_value: done_location_ids})
  end
end
