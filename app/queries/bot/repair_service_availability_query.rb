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

      statuses = spare_parts.map { |spare_part| part_status(spare_part, store) }
      return UNKNOWN if statuses.include?(UNKNOWN)
      return OUT_OF_STOCK if statuses.include?(OUT_OF_STOCK)

      IN_STOCK
    end

    private

    def part_status(spare_part, store)
      product = spare_part.product
      return UNKNOWN unless product
      return UNKNOWN if product.items.empty?

      quantity = product.quantity_in_store(store)
      return UNKNOWN unless quantity.is_a?(Numeric)

      quantity.positive? ? IN_STOCK : OUT_OF_STOCK
    end
  end
end
