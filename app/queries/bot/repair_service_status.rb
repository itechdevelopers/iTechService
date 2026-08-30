# frozen_string_literal: true

module Bot
  module RepairServiceStatus
    LEGACY = { 'many' => 'in_stock', 'low' => 'in_stock', 'none' => 'out_of_stock' }.freeze
    BUSINESS = { 'many' => 'sufficient', 'low' => 'low_requires_confirmation', 'none' => 'unavailable' }.freeze

    module_function

    def raw(repair_service, department)
      store = department&.spare_parts_store
      return nil unless store

      repair_service.remnants_s(store)
    rescue StandardError
      nil
    end

    def legacy(repair_service, department)
      return 'not_required' if repair_service.spare_parts.empty?

      LEGACY.fetch(raw(repair_service, department), 'unknown')
    end

    def business(repair_service, department)
      return 'not_required' if repair_service.spare_parts.empty?

      BUSINESS.fetch(raw(repair_service, department), 'unknown')
    end
  end
end
