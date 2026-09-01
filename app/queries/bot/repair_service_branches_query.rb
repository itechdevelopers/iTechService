# frozen_string_literal: true

module Bot
  # Finds customer departments that have a price for each matching service.
  class RepairServiceBranchesQuery
    Result = Struct.new(:repair_service, :departments)

    def initialize(product_id: nil, model: nil, service: nil, limit: 50)
      @product_id = product_id
      @model = model.to_s.strip
      @service = service.to_s.strip
      @limit = limit.to_i.clamp(1, 100)
    end

    def call
      services.map do |repair_service|
        ids = repair_service.prices.filter_map(&:department_id).uniq
        departments = Department.real.participating_in_repair_services.where(id: ids).to_a
        Result.new(repair_service, departments)
      end.select { |result| result.departments.any? }
    end

    private

    def services
      products = if @product_id.present?
                   Product.not_archived.where(id: @product_id)
                 else
                   Product.not_archived.where('products.name ILIKE ?', "%#{sanitize_like(@model)}%")
                          .order(:name, :id).limit(@limit)
                 end
      scope = RepairService.not_archived.joins(:products)
                           .where(products: { id: products.select(:id) })
      scope = scope.where('repair_services.name ILIKE ?', "%#{sanitize_like(@service)}%") if @service.present?
      scope.includes(:prices).distinct.order(:name, :id).limit(@limit).to_a
    end

    def sanitize_like(value)
      value.to_s.gsub(/[\\%_]/) { |character| "\\#{character}" }
    end
  end
end
