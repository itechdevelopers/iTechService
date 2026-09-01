# frozen_string_literal: true

module Bot
  class RepairServiceBranchesPresenter
    def initialize(result)
      @result = result
    end

    def as_json
      {
        service_id: @result.repair_service.id,
        service_name: @result.repair_service.name,
        departments: @result.departments.map { |d| { id: d.id, name: d.name, city: d.city_name } }
      }
    end
  end
end
