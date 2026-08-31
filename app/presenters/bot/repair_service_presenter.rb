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
          status: (legacy_status = Bot::RepairServiceStatus.legacy(@repair_service, @department)),
          business_status: Bot::RepairServiceStatus.business(@repair_service, @department)
        },
        branch: Bot::DepartmentMetadataPresenter.as_json(@department),
        active: !@repair_service.archived?,
        customer_info: plain_text(@repair_service.client_info),
        warranty: warranty_json,
        reasons: reasons_json,
        special_marks: begin
          text = plain_text(@repair_service.special_marks)
          text.present? ? [{ text: text, source: 'repair_service' }] : []
        end
      }
    end

    def warranty_json
      terms = @repair_service.spare_parts.includes(:product).map do |part|
        part.warranty_term.presence || part.product&.warranty_term
      end.compact.map(&:to_s).uniq
      return nil unless terms.one?

      { term: terms.first, display: "#{terms.first} месяцев" }
    end

    def reasons_json
      @repair_service.repair_causes.order(:id).map { |cause| { id: cause.id, name: cause.title } }
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
