# frozen_string_literal: true

module Bot
  class DepartmentMetadataPresenter
    def self.as_json(department)
      {
        id: department.id,
        name: department.name,
        city: department.city_name,
        repair_participating: department.participates_in_repair_services?,
        address: Setting.get_value('address', department).presence || department.address.presence,
        contact_phone: Setting.get_value('contact_phone', department).presence || department.contact_phone.presence,
        working_hours: schedule(department)
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

    def self.schedule(department)
      configured = Setting.get_value('schedule', department).presence
      return configured if configured

      working_hours(department)
    end
    private_class_method :working_hours, :schedule
  end
end
