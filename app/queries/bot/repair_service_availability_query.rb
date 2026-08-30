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
      Bot::RepairServiceStatus.legacy(@repair_service, @department)
    end
  end
end
