# frozen_string_literal: true

module Bot
  # Calculates a customer-safe spare-parts availability status without
  # creating stock records or exposing internal inventory data.
  class RepairServiceAvailabilityQuery
    IN_STOCK = 'in_stock'.freeze
    OUT_OF_STOCK = 'out_of_stock'.freeze
    NOT_REQUIRED = 'not_required'.freeze
    UNKNOWN = 'unknown'.freeze

    def initialize(repair_service:, department:)
      @repair_service = repair_service
      @department = department
    end

    def call
      spare_parts = @repair_service.spare_parts.to_a
      return NOT_REQUIRED if spare_parts.empty?

      store = @department&.spare_parts_store
      return UNKNOWN unless store
      # RepairService#remnants_s is AIS' authoritative aggregate across all
      # required spare parts. Keep the legacy status contract while exposing the
      # richer business_status in the presenter.
      case @repair_service.remnants_s(store)
      when 'many', 'low' then IN_STOCK
      when 'none' then OUT_OF_STOCK
      else UNKNOWN
      end
    end
  end
end
