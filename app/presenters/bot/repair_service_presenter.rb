# frozen_string_literal: true

module Bot
  # Client-safe representation of one catalog repair service and branch price.
  class RepairServicePresenter
    def initialize(product:, repair_service:, department:, price:)
      @product = product
      @repair_service = repair_service
      @department = department
      @price = price
    end

    def as_json
      {
        id: @repair_service.id,
        model: { id: @product.id, name: @product.name },
        service: @repair_service.name,
        price: price_json,
        availability: {
          status: Bot::RepairServiceAvailabilityQuery.new(
            repair_service: @repair_service,
            department: @department
          ).call
        },
        branch: {
          id: @department.id,
          name: @department.name,
          city: @department.city_name
        },
        active: !@repair_service.archived?
      }
    end

    private

    def price_json
      return nil unless @price

      if @price.is_range_price?
        {
          type: 'range',
          amount: nil,
          from: decimal(@price.value_from),
          to: decimal(@price.value_to)
        }
      else
        {
          type: 'fixed',
          amount: decimal(@price.value),
          from: nil,
          to: nil
        }
      end
    end

    def decimal(value)
      value&.to_d&.to_s('F')
    end
  end
end
