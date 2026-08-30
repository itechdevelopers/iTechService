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
          status: (legacy_status = Bot::RepairServiceAvailabilityQuery.new(
            repair_service: @repair_service,
            department: @department
          ).call),
          business_status: { 'many' => 'sufficient', 'low' => 'low_requires_confirmation', 'none' => 'unavailable' }[@repair_service.remnants_s(@department.spare_parts_store)] || (legacy_status == 'not_required' ? 'not_required' : 'unknown')
        },
        branch: {
          id: @department.id,
          name: @department.name,
          city: @department.city_name,
          repair_participating: @department.participates_in_repair_services?
        },
        active: !@repair_service.archived?,
        customer_info: plain_text(@repair_service.client_info),
        special_marks: begin
          text = plain_text(@repair_service.special_marks)
          text.present? ? [{ text: text, source: 'repair_service' }] : []
        end
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

    def plain_text(value)
      return nil unless value.present?

      CGI.unescapeHTML(value.to_s).gsub(/<[^>]*>/, ' ').squish
    end
  end
end
