# frozen_string_literal: true

module Bot
  class RepairCatalogPresenter
    def initialize(repair_service:, department: nil)
      @repair_service = repair_service
      @department = department
    end

    def as_json
      {
        id: @repair_service.id,
        name: @repair_service.name,
        active: !@repair_service.archived?,
        customer_info: plain_text(@repair_service.client_info),
        special_marks: special_marks,
        products: @repair_service.products.map { |p| { id: p.id, name: p.name } },
        branch: branch_json,
        price: price_json,
        availability: availability_json
      }
    end

    private

    def special_marks
      text = plain_text(@repair_service.special_marks)
      text.present? ? [{ text: text, source: 'repair_service' }] : []
    end

    def branch_json
      return nil unless @department

      {
        id: @department.id,
        name: @department.name,
        city: @department.city_name,
        repair_participating: @department.participates_in_repair_services?
      }
    end

    def price_json
      return nil unless @department

      price = @repair_service.price(@department)
      return nil unless price

      price.is_range_price? ? { type: 'range', amount: nil, from: decimal(price.value_from), to: decimal(price.value_to) } :
        { type: 'fixed', amount: decimal(price.value), from: nil, to: nil }
    end

    def availability_json
      return { status: 'unknown', business_status: 'unknown' } unless @department

      { status: Bot::RepairServiceStatus.legacy(@repair_service, @department), business_status: Bot::RepairServiceStatus.business(@repair_service, @department) }
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
