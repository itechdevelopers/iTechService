# frozen_string_literal: true

module Bot
  class DepartmentMetadataPresenter
    def self.as_json(department)
      {
        id: department.id,
        name: department.name,
        city: department.city_name,
        repair_participating: department.participates_in_repair_services?,
        address: department.address.presence,
        contact_phone: department.contact_phone.presence,
        working_hours: working_hours(department)
      }
    end

    def self.working_hours(department)
      return nil unless department.respond_to?(:working_hours)

      entries = department.working_hours.ordered.map do |entry|
        {
          day: entry.day_name_short,
          opens_at: entry.opens_at&.strftime('%H:%M'),
          closes_at: entry.closes_at&.strftime('%H:%M'),
          closed: entry.is_closed?
        }
      end
      entries.presence
    end
    private_class_method :working_hours
  end
end
