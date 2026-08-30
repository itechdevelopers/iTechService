# frozen_string_literal: true

module Bot
  # Looks up active repair services for catalog products and one service branch.
  class RepairServicesQuery
    ProductNotFound = Class.new(StandardError)
    Result = Struct.new(:product, :repair_service, :price)

    # Bounded, read-only catalog query used by the middleware vocabulary refresh.
    # It deliberately preloads only customer-safe relations and never inventory rows
    # into the serialized response.
    def self.catalog(model: nil, product_id: nil, limit: 100, active_only: true)
      scope = RepairService.not_archived
      scope = scope.includes(:products, :prices, spare_parts: { product: { items: :store_items } })
      if product_id.present?
        scope = scope.joins(:products).where(products: { id: product_id })
      elsif model.to_s.strip.present?
        scope = scope.joins(:products).where('products.name ILIKE ?', "%#{ActiveRecord::Base.send(:sanitize_sql_like, model.to_s.strip)}%")
      end
      scope.distinct.order(:name, :id).limit(limit.to_i.clamp(1, 100)).to_a
    end

    def initialize(department:, product_id: nil, model: nil, service: nil, limit: 50)
      @department = department
      @product_id = product_id
      @model = model.to_s.strip
      @service = service.to_s.strip
      @limit = limit.to_i.clamp(1, 100)
    end

    def call
      products.flat_map do |product|
        services_for(product).map do |repair_service|
          Result.new(product, repair_service, repair_service.price(@department))
        end
      end.first(@limit)
    end

    private

    def products
      scope = Product.not_archived

      if @product_id.present?
        product = scope.find_by(id: @product_id)
        raise ProductNotFound unless product

        [product]
      else
        scope.where('products.name ILIKE ?', "%#{sanitize_like(@model)}%")
             .order(:name, :id)
             .limit(@limit)
             .to_a
      end
    end

    def services_for(product)
      scope = product.repair_services.not_archived.includes(
        :prices,
        spare_parts: { product: { items: :store_items } }
      )
      scope = scope.where('repair_services.name ILIKE ?', "%#{sanitize_like(@service)}%") if @service.present?
      scope.order(:name, :id).to_a
    end

    def sanitize_like(value)
      ActiveRecord::Base.send(:sanitize_sql_like, value)
    end
  end
end
