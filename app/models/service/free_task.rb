module Service
  class FreeTask < ApplicationRecord
    self.table_name = 'service_free_tasks'
    mount_uploader :icon, IconUploader

    def to_s
      name
    end

    def possible_performers(department = Department.current)
      return User.none if code.nil?

      locations = Location.in_department(department).code_start_with(code)
      locations.any? ? User.active.where(location_id: locations) : User.none
    end
  end
end
