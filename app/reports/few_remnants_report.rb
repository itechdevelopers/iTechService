class FewRemnantsReport < BaseReport
  attr_accessor :kind

  def name
    "#{super}_#{kind}"
  end

  def base_name
    'few_remnants'
  end

  def call
    result[:stores] = {}
    result[:products] = {}
    products = Product.send(kind)
    stores = Store.visible
                  .send(kind == :goods ? :retail : :spare_parts)
                  .order('id asc')
    stores = stores.in_department(department) if department
    stores.each do |store|
      result[:stores].store store.id.to_s, { code: store.code, name: store.name }
    end
    products.each do |product|
      remnants = {}
      stores.each do |store|
        if product.quantity_threshold.present? &&
          (qty = product.quantity_in_store(store)) <= product.quantity_threshold
          remnants.store store.id.to_s, qty
        end
      end
      unless remnants.empty?
        result[:products].store product.id.to_s, { code: product.code, name: product.name, threshold: product.quantity_threshold, remnants: remnants }
      end
    end
    result
  end
end
